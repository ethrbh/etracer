%%% -------------------------------------------------------------------
%%% Author  : ETHRBH
%%% Description :
%%%
%%% Created : Jul 2, 2012
%%% -------------------------------------------------------------------
-module(etracer_worker).

-behaviour(gen_server).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("../include/etracer.hrl").

%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([]).

%% --------------------------------------------------------------------
%% gen_server callbacks
%% --------------------------------------------------------------------
-export([start/2, stop/1]).
-export([create_trace_match_specification/1, get_trace_flag_for_dbg/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------
-record(state, {
				clientPid,				
				config = [],	%% list of tuple
				check_erlang_node_availability_tref
			   }).

%% --------------------------------------------------------------------
%% Define
%% --------------------------------------------------------------------
-define(SERVER(Name), begin
						  erlang:list_to_atom(erlang:atom_to_list(?MODULE)++"_"++Name)
					  end).

%% 500 msec
-define(CHECK_ERLANGNODE_AVAILABILITY_TIME, 500).

%% ====================================================================
%% External functions
%% ====================================================================


%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% @spec start(Name, Config) ->	ok | {error, Reason}
%% ETracerConfigName	=	string()
%% Config				=	list of tuple
%% @doc
%% @end
%% --------------------------------------------------------------------
start(ETracerConfigName, Config) when is_list(ETracerConfigName) ->
	NewLineChar = etracer:get_new_line_char(),
	NewConfig = lists:append(Config, [{newLineChar, NewLineChar}]),
	
	Server = ?SERVER(ETracerConfigName),
	case catch gen_server:start({local, Server}, ?MODULE, [NewConfig], []) of
		{ok, _Pid} ->
			ok;
		
		{error, Reason} ->
			error_logger:error_report(["Starting "++erlang:atom_to_list(Server)++" has failed", {reason, {error, Reason}}, {module, ?MODULE}, {line, ?LINE}]),
			{error, Reason};
		
		Reason ->
			error_logger:error_report(["Starting "++erlang:atom_to_list(Server)++" has failed", {reason, Reason}, {module, ?MODULE}, {line, ?LINE}]),
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% @spec stop(%% ETracerConfigName	=	string()) ->	ok | {error, Reason}
%% ETracerConfigName	=	string()
%% @doc
%% @end
%% --------------------------------------------------------------------
stop(ETracerConfigName) when is_list(ETracerConfigName) ->
	%% Stop tracing
	Server = ?SERVER(ETracerConfigName),
	case whereis(Server) of
		Pid when is_pid(Pid) ->
			case catch gen_server:call(Server, {stop}, ?GEN_SERVER_CALL_TO) of
				ok ->
					error_logger:info_report([erlang:atom_to_list(Server)++" has stopped", {pid, Pid}]),
					ok;
				{error, Reason} ->
					{error, Reason};
				Reason ->
					{error, Reason}
			end;
		Reason ->
			{error, Reason}
	end.


%% --------------------------------------------------------------------
%% Generate Trace Match Specification list by its flag already set
%% Input:
%%		ETracerConfigName	:	string
%% Output:
%%		TraceMatchSpec		:	list, example [{'_',[],[{{message},{process_dump}},{return_trace}]}]
%% --------------------------------------------------------------------
create_trace_match_specification(ETracerConfigName) ->
	%% This function will to give the match specifucation for the dbg:tpl...
	%% Input:  MatchSpecFlag
	%% Output:  MatchSpec  like this: [{'_',[],[{{message},{process_dump}},{return_trace}]}]

	case etracer:get_etracer_config_record(ETracerConfigName) of
		{ok, TabRec} when is_record(TabRec, rETracerConfig)->
			MatchHead = '_',
			MatchCondition = [],
			MatchBody = create_trace_match_specification_loop(TabRec#rETracerConfig.trace_match_spec_flags, []),
			MatchSpec = [{MatchHead, MatchCondition, MatchBody}],
			MatchSpec;
		_->	[]
	end.

create_trace_match_specification_loop([], TraceMatchSpec) ->
	TraceMatchSpec;
create_trace_match_specification_loop([H|T], TraceMatchSpec) ->
	case H of
		message ->
			create_trace_match_specification_loop(T, lists:append([{message}], TraceMatchSpec));
		process_dump ->
			create_trace_match_specification_loop(T, lists:append([{process_dump}], TraceMatchSpec));
		return_trace ->
			create_trace_match_specification_loop(T, lists:append([{return_trace}], TraceMatchSpec))
	end.

%% --------------------------------------------------------------------
%% Give the Trace Flags using in DBG
%% Input:
%%		TraceFlags		:	list of atom
%% Output:
%%		NewTraceFlags	:	list of atom
%% --------------------------------------------------------------------
get_trace_flag_for_dbg(TraceFlags) ->
	TraceflagList = [begin
						 TraceFlagRec = #rTraceFlags{},
						 %% Find the value of flag in its own record
						 lists:nth(commonDB:get_record_element_pos(TraceFlag, rTraceFlags)+1, erlang:tuple_to_list(TraceFlagRec))
					 end || TraceFlag <- TraceFlags],
	lists:append([TraceflagList, [timestamp]]).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([Config]) ->
	NewConfig = lists:append(Config, [{clientPid, undefined}]),
	
	case start_dbg(NewConfig) of
		{ok, ClientPid} ->
			
			%% Start periodically timer for checking Erlang node availability
			{ok, TRef} = timer:send_interval(?CHECK_ERLANGNODE_AVAILABILITY_TIME, self(), {check_erlang_node}),
			
			NewConfig2 = lists:keyreplace(clientPid, 1, NewConfig, {clientPid, ClientPid}),
			
			{ok, #state{config = NewConfig2, 
						clientPid = ClientPid,
						check_erlang_node_availability_tref = TRef}};
		{error, Reason} ->
			{{error, Reason}, #state{}}
	end.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call({stop}, _From, State) ->
	catch timer:cancel(State#state.check_erlang_node_availability_tref),
	
	%% Close Logfile if it is opened
	case proplists:get_value(logDirection, State#state.config) of
		{ok, IoDevice} ->
			fileHandling:closeFile(IoDevice);
		_->	do_nothing
	end,
	
	case stop_dbg(State#state.config, State#state.clientPid) of
		stopped ->
			{stop, normal, stopped, State};
		{error, nodedown} ->
			{stop, normal, stopped, State};
		Reason ->
			{stop, normal, Reason, State}
	end;

handle_call(Request, From, State) ->
	error_logger:info_report(["handle_call", {request, Request}, {from, From}, {state, State}, {module, ?MODULE}, {line, ?LINE}]),
    Reply = ok,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(Msg, State) ->
	error_logger:info_report(["handle_cast", {msg, Msg}, {state, State}, {module, ?MODULE}, {line, ?LINE}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({check_erlang_node}, State) ->
	case do_check_node_and_restart_dbg(State#state.config) of
		{ok, ClientPid} ->
			NewConfig = lists:keyreplace(clientPid, 1, State#state.config, {clientPid, ClientPid}),
			
			case ClientPid of
				undefined ->
					etrace_worker_handler(NewConfig, {nodedown}, 0);
				_->	ok
			end,
			
			{noreply, State#state{clientPid = ClientPid,
								  config = NewConfig}};
		{error, _Reason} ->
			{noreply, State}
	end;

handle_info(Info, State) ->
	error_logger:info_report(["handle_info", {info, Info}, {state, State}, {module, ?MODULE}, {line, ?LINE}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	%%error_logger:info_report(["Terminate", {reason, Reason}, {state, State}, {module, ?MODULE}, {line, ?LINE}]),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Stop DBG on external node
%% Input:
%%		Config		:	list of tuple
%%		ClientPid	:	pid() | undefined
%% Output:
%%		stopped | {error, Reason}
%% --------------------------------------------------------------------
stop_dbg(Config, ClientPid) ->
	ErlangNode = proplists:get_value(erlangNode, Config),
	ErlangNodeCookie = proplists:get_value(erlangNodeCookie, Config),
	
	%% Setup Cookie
	erlang:set_cookie(ErlangNode, ErlangNodeCookie),
	
	case net_adm:ping(ErlangNode) of
		pong ->
			%% Stop DBG
			rpc:call(ErlangNode, dbg, ctpl, []),
			case catch rpc:call(ErlangNode, dbg, stop_clear, []) of
				stopped ->
					case ClientPid of
						P when is_pid(P) ->
							catch dbg:stop_trace_client(P);
						_->	do_nothing
					end,
					
					rpc:call(ErlangNode, dbg, stop, []),
					
					stopped;
				Reason ->
					{error, Reason}
			end;
		_->	%% Node is not alive
			{error, nodedown}
	end.
		
%% --------------------------------------------------------------------
%% Start DBG trace on node
%% Input:
%%		Config	:	list of tuple
%% Output:
%%		{ok, ClientPid} | {error, Reason}
%% --------------------------------------------------------------------
start_dbg(Config) ->
	case do_check_node_and_restart_dbg(Config) of
		{ok, ClientPid} ->
			{ok, ClientPid};
		{error, Reason} ->
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% Restart DBG
%% Input:
%%		Config	:	list of tuple
%% Output:
%%		{ok, ClientPid} | {error, Reason}
%% --------------------------------------------------------------------
do_check_node_and_restart_dbg(Config) ->
	%% Starting DBG...
	ErlangNode = proplists:get_value(erlangNode, Config),
	ErlangNodeCookie = proplists:get_value(erlangNodeCookie, Config),
	ETracerConfigName = proplists:get_value(eTracerConfigName, Config),
	
	case etracer:get_etracer_config_record(ETracerConfigName) of
		{ok, TabRec} when is_record(TabRec, rETracerConfig)->
	
			%% Setup Cookie
			erlang:set_cookie(ErlangNode, ErlangNodeCookie),
			
			case net_adm:ping(ErlangNode) of
				pong ->
					
					%% Check clientPid in Config. The tracing is already started and it is ok when clientPid is an erlang Pid, otherwise NOT.
					%% In this case must restart tracing.
					
					case proplists:get_value(clientPid, Config) of
						ClientPidOld when is_pid(ClientPidOld) ->
							{ok, ClientPidOld};
						
						_->	%% Stop DBG first...
							stop_dbg(Config, proplists:get_value(clientPid, Config)),
							
							{ok, TracerPort} = etracer:get_next_tracer_port(),
							{ok, MessageQueSize} = etracer:get_tracer_message_queue_size(),
							
							case catch rpc:call(ErlangNode, dbg, tracer, [port, rpc:call(ErlangNode, dbg, trace_port, [ip, {TracerPort, MessageQueSize}])]) of
								{ok, Pid} ->
									error_logger:info_report(["DBG tracer has been started", {node, ErlangNode}, {cookie, ErlangNodeCookie}, {port, TracerPort}, {msg_queue_size, MessageQueSize}, {pid, Pid}, {module, ?MODULE}, {line, ?LINE}]),
									
									%% Setup Tracemeasure
									set_trace_measure(ETracerConfigName),
									
									%% Get remote host
									[_,RemoteHost] = string:tokens(atom_to_list(ErlangNode), "@"),
									
									%% Start the DBG client on the local node for catching trace message from traced node
									ClientPid = dbg:trace_client(ip, {RemoteHost, TracerPort},{fun(A, B) -> etrace_worker_handler(Config, A, B) end, 0}),
									
									{ok, ClientPid};
								
								{error, already_started} ->
									{error, already_started}
							end
					end;
				
				_->	%% ErlangNode is DOWN...try again...
					{ok, undefined}
			end;
		
		{error, Reason} ->
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% Trace message handler from traced node
%% Input:
%%		Config	:	list of tuple
%%		A		:	trace data
%%		B		:	integer, trace flag, 0 -> trace data
%%										 1 -> nothing
%% Output:
%%		B		:	integer, trace flag
%% --------------------------------------------------------------------
etrace_worker_handler(Config, A, B) ->
	case B of
		1 ->
			B;
		0 ->
			%% Handle trace message
			do_etrace_worker_handler(Config, A),
			B
	end.

%% --------------------------------------------------------------------
%% Handle trace message from traced node
%% Input:
%%		Config	:	list of tuple
%%		Data	:	trace data
%% Output:
%%		ok
%% --------------------------------------------------------------------
do_etrace_worker_handler(Config, Data) ->
	ErlangNode = proplists:get_value(erlangNode, Config),
	ETracerConfigName = proplists:get_value(eTracerConfigName, Config),
	NewLineChar = proplists:get_value(newLineChar, Config),
	LogDestination = proplists:get_value(logDestination, Config),
	
	{Header, Line} = case Data of
						 {nodedown} ->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode, get_timestamp(node())]),
							 Str = io_lib:format("The ErlangNode is DOWN",[]),
							 {HeaderStr, Str};
							 
						 %% The call type message is received...
						 {trace,Pid,call,Msg}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode, get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,call,~p}",[Pid, Msg]),
							 {HeaderStr, Str};
						 
						 {trace_ts,Pid,call,Msg,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode, get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,call,~p}", [Pid, Msg]),
							 {HeaderStr, Str};
						 
						 %% The call type message is received...
						 {trace,Pid,call,Msg,BinData}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 UnpackedBinData = unpack_bindata(BinData),
							 StrTmp = io_lib:format("{trace,~p,call,~p",[Pid,Msg]),
							 
							 {HeaderStr, StrTmp++NewLineChar++get_bindata_as_string(UnpackedBinData, NewLineChar)++"}"++NewLineChar};
						 
						 {trace_ts,Pid,call,Msg,BinData,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 UnpackedBinData = unpack_bindata(BinData),
							 StrTmp = io_lib:format("{trace_ts,~p,call,~p",[Pid,Msg]),
							 
							 {HeaderStr, StrTmp++NewLineChar++get_bindata_as_string(UnpackedBinData, NewLineChar)++"}"++NewLineChar};
						 
						 %% The spawn type message is received...
						 {trace, Pid, spawn, Pid2, {M, F, A}}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = case A of
									   [{V1,V2,V3,V4,V5,V6},V7,V8,BinData]  ->
										   UnpackedBinData = unpack_bindata(BinData),
										   io_lib:format("{trace ~p spawn ~p,{~p:~p/",[Pid,Pid2,M,F]) ++ io_lib:format("{~p,~p,~p,~p,~p,~p},~p,~p,~p",[V1,V2,V3,V4,V5,V6,V7,V8,UnpackedBinData]++"}}");
									   
									   [{V1,V2,V3,V4,V5,V6},V7,V8,BinData,V9]  ->
										   UnpackedBinData = unpack_bindata(BinData),
										   io_lib:format("{trace ~p spawn ~p,{~p:~p/",[Pid,Pid2,M,F]) ++ io_lib:format("{~p,~p,~p,~p,~p,~p},~p,~p,~p,~p}}",[V1,V2,V3,V4,V5,V6,V7,V8,UnpackedBinData,V9]);
									   
									   _-> io_lib:format("{trace ~p spawn ~p,{~p:~p/~p}}",[Pid,Pid2,M,F,A])
								   end,
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, spawn, Pid2, {M, F, A},TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = case A of
									   [{V1,V2,V3,V4,V5,V6},V7,V8,BinData]  ->
										   UnpackedBinData = unpack_bindata(BinData),
										   io_lib:format("{trace_ts ~p spawn ~p,~p:~p",[Pid,Pid2,M,F]) ++ io_lib:format("{~p,~p,~p,~p,~p,~p},~p,~p,~p",[V1,V2,V3,V4,V5,V6,V7,V8,UnpackedBinData]++"}}");
									   
									   [{V1,V2,V3,V4,V5,V6},V7,V8,BinData,V9]  ->
										   UnpackedBinData = unpack_bindata(BinData),
										   io_lib:format("{trace_ts ~p spawn ~p,~p:~p",[Pid,Pid2,M,F]) ++ io_lib:format("{~p,~p,~p,~p,~p,~p},~p,~p,~p,~p}}",[V1,V2,V3,V4,V5,V6,V7,V8,UnpackedBinData,V9]);
									   
									   _-> io_lib:format("{trace_ts ~p spawn ~p,{~p:~p/~p}}",[Pid,Pid2,M,F,A])
								   end,
							 {HeaderStr, Str};
						 
						 %% A ReturnVaue is received...
						 {trace,Pid,return_from,{M,F,A},ReturnValue}  ->  
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{{trace,~p,return_from{~p:~p/~p} ~p}",[Pid,M,F,A,ReturnValue]),
							 {HeaderStr, Str};
						 
						 {trace_ts,Pid,return_from,{M,F,A},ReturnValue,TimeStamp}  ->  
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{{trace_ts,~p,return_from{~p:~p/~p} ~p}",[Pid,M,F,A,ReturnValue]),
							 {HeaderStr, Str};
						 
						 {trace,Pid,return_to,{M,F,A}}  ->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,return_to{~p:~p/~p}}",[Pid,M,F,A]),
							 {HeaderStr, Str};
						 
						 {trace,Pid,return_to,undefined}  ->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,return_to undefined}",[Pid]),
							 {HeaderStr, Str};
						 
						 {trace_ts,Pid,return_to,{M,F,A},TimeStamp}  ->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,return_to{~p:~p/~p}}",[Pid,M,F,A]),
							 {HeaderStr, Str};
						 
						 {trace_ts,Pid,return_to,undefined,TimeStamp}  ->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,return_to undefined }",[Pid]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, 'receive', Msg}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,receive,~p}",[Pid,Msg]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, 'receive', Msg,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,receive,~p}",[Pid,Msg]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, send, Msg, To}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,send,~p,~p}",[Pid,Msg,To]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, send, Msg, To,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,send,~p,~p}",[Pid,Msg,To]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, send_to_non_existing_process, Msg, To}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,send_to_non_existing_process,~p,~p}",[Pid,Msg,To]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, send_to_non_existing_process, Msg, To,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,send_to_non_existing_process,~p,~p}",[Pid,Msg,To]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, exit, Reason}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,exit,~p}",[Pid,Reason]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, exit, Reason,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,exit,~p}",[Pid,Reason]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, link, Pid2}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,link,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, link, Pid2,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,link,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, unlink, Pid2}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,unlink,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, unlink, Pid2,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,unlink,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, getting_linked, Pid2}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,getting_linked,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, getting_linked, Pid2,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,getting_linked,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, getting_unlinked, Pid2}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,getting_unlinked,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, getting_unlinked, Pid2,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,getting_unlinked,~p}",[Pid,Pid2]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, register, Name}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,register,~p}",[Pid,Name]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, register, Name,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,register,~p}",[Pid,Name]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, unregister, Name}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,unregister,~p}",[Pid,Name]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, unregister, Name,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,unregister,~p}",[Pid,Name]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, in, {M,F,A}}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,in,{~p,~p,~p}}",[Pid,M,F,A]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, in, {M,F,A},TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,in,{~p,~p,~p}}",[Pid,M,F,A]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, out, {M,F,A}}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,out,{~p,~p,~p}}",[Pid,M,F,A]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, out, {M,F,A},TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,out,{~p,~p,~p}}",[Pid,M,F,A]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, gc_start, Info}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,gc_start,~p}",[Pid,Info]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, gc_start, Info,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,gc_start,~p}",[Pid,Info]),
							 {HeaderStr, Str};
						 
						 {trace, Pid, gc_end, Info}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("{trace,~p,gc_end,~p}",[Pid,Info]),
							 {HeaderStr, Str};
						 
						 {trace_ts, Pid, gc_end, Info,TimeStamp}->
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(TimeStamp)]),
							 Str = io_lib:format("{trace_ts,~p,gc_end,~p}",[Pid,Info]),
							 {HeaderStr, Str};
						 
						 _-> %% Un-recognize value...put all of them to the output
							 HeaderStr = io_lib:format("##### ~s ~s", [ErlangNode,get_timestamp(ErlangNode)]),
							 Str = io_lib:format("~p",[Data]),
							 {HeaderStr, Str}
					 end,
	
	put_Trace2Output(LogDestination,{ETracerConfigName, Header}),
	put_Trace2Output(LogDestination,{ETracerConfigName, Line++NewLineChar}).

%% --------------------------------------------------------------------
%% Get the TimeStamp in erlang node
%% Input:
%%		ErlangNode	:	atom, name of the node
%% Output:
%%		TimeStamp	:	Data_and_Time format
%% --------------------------------------------------------------------
get_timestamp(ErlangNode) when is_atom(ErlangNode) ->
	case net_adm:ping(ErlangNode) of
		pong ->
			%% Get the time from thr remote erlang node for timestamp
			Now = rpc:call(ErlangNode,erlang,now,[]),
			{_, _, MicroSec} = Now,
			{Date, Time} = rpc:call(ErlangNode,calendar,now_to_local_time,[Now]),
			DateStr = io_lib:format("~4w-~2.2.0w-~2.2.0w ", tuple_to_list(Date)),
			TimeStr = DateStr ++ io_lib:format("~2.2.0w:~2.2.0w:~2.2.0w:", tuple_to_list(Time)),
			TimeStamp = TimeStr ++ io_lib:format("~3.3.0w", [round((MicroSec/1000)-0.5)]),
			TimeStamp;
		
		_->	%% Node is down
			"node_is_dow"
	end;

%% --------------------------------------------------------------------
%% Give the timestamp from now()
%% Input:
%%		TimeStamp	:	now()
%% Output:
%%		TimeStamp	:	Data_and_Time format
%% --------------------------------------------------------------------
get_timestamp(Now) when is_tuple(Now)->
  {_, _, MicroSec} = Now,
  {Date, Time} = calendar:now_to_local_time(Now),
  DateStr = io_lib:format("~4w-~2.2.0w-~2.2.0w ", tuple_to_list(Date)),
  TimeStr = DateStr ++ io_lib:format("~2.2.0w:~2.2.0w:~2.2.0w:", tuple_to_list(Time)),
  TimeStamp = TimeStr ++ io_lib:format("~3.3.0w", [round((MicroSec/1000)-0.5)]),
  TimeStamp.

%% --------------------------------------------------------------------
%% Put trace info int the "Trace window"
%% Input:
%%		Destination	:	editor | {ok, IoDevice}
%%		Data		:	tuple, {ETracerConfigName, TraceData}
%% Output:
%%		ok	| {error, Reason}
%% --------------------------------------------------------------------
put_Trace2Output(Destination, Data)->
	{ETracerConfigName, TraceData} = Data,
	
	enotebook:appendTraceLog(Destination, ETracerConfigName, TraceData++"\n").

%% %% --------------------------------------------------------------------
%% %% Write all data into "Tracer window"
%% %% Input:
%% %%		ETracerConfigName	:	string
%% %%		ListOfTraceInfo		:	list of string
%% %% Output:
%% %%		ok
%% %% --------------------------------------------------------------------
%% writebindata2editor(_ETracerConfigName, [])->
%%   ok;
%% writebindata2editor(ETracerConfigName, [Head | Tail])->
%%   put_Trace2Output(editor,{ETracerConfigName, io_lib:format("~p~n",[Head])}),
%%   writebindata2editor(ETracerConfigName, Tail).

%% --------------------------------------------------------------------
%% Get Binary data as string
%% Input:
%%		ListOfTraceInfo		:	list of string
%%		NewLineChar			:	string, the new line char
%% Output:
%%		Str					:	string
%% --------------------------------------------------------------------
get_bindata_as_string(ListOfTraceInfo, NewLineChar) ->
	get_bindata_as_string_loop(ListOfTraceInfo, NewLineChar, "").

get_bindata_as_string_loop([], _, Str)->
	Str;
get_bindata_as_string_loop([Head | Tail], NewLineChar, Str)->
	%%put_Trace2Output(editor,{ETracerConfigName, io_lib:format("~p~n",[Head])}),
	NewStr = Str++io_lib:format("~p"++NewLineChar,[Head]),
	get_bindata_as_string_loop(Tail, NewLineChar, NewStr).

%% --------------------------------------------------------------------
%% Unpack binary trace data
%% Input:
%%		BinData	:	binary data
%% Output:
%%		ok
%% --------------------------------------------------------------------
unpack_bindata(BinData)->
	%%string:tokens(binary_to_list(BinData),"\n").
	
	BinDataListOrig = string:tokens(binary_to_list(BinData),"\n"),
	unpack_bindataLoop(BinDataListOrig,[]).

unpack_bindataLoop([],ResultList)->
	lists:reverse(ResultList);
unpack_bindataLoop([Head | Tail],ResultList)->
	case string:str(Head,"Return addr") of
		0 ->
			case string:str(Head,"cp =") of
				0->
					unpack_bindataLoop(Tail,ResultList);
				_->
					[_,Str|_] = string:tokens(Head,"()+"),
					unpack_bindataLoop(Tail,[Str | ResultList])
			end;
		_->
			case string:str(Head,"terminate process normally") of
				0 ->
					[_,Str|_] = string:tokens(Head,"()+"),
					unpack_bindataLoop(Tail,[Str | ResultList]);
				_-> unpack_bindataLoop(Tail,ResultList)
			end
	end.

%% --------------------------------------------------------------------
%% Setup Trace Measure
%% Input:
%%		ETracerConfigName	:	string
%% Output:
%%		ok | {error, Reason}
%% --------------------------------------------------------------------
set_trace_measure(ETracerConfigName) ->
	case etracer:get_etracer_config_record(ETracerConfigName) of
		{ok, TabRec} when is_record(TabRec, rETracerConfig)->
			
			ErlangNode = TabRec#rETracerConfig.erlang_node,
			ErlangNodeCookie = TabRec#rETracerConfig.erlang_node_cookie,
			erlang:set_cookie(ErlangNode, ErlangNodeCookie),
			
			%% Clear all previously trace...
			rpc:call(ErlangNode, dbg, ctpl, []),
		  	
			%% s (send)    Traces the messages the process sends.
			%% r ('receive')Traces the messages the process receives.
			%% m (messages)  Traces the messages the process receives and sends.
			%% c (call)    Traces global function calls for the process according to the trace patterns set in the system (see tp/2).
			%% p (procs)    Traces process related events to the process.
			%% Add timestamp for default in the traceflag list
			TraceflagList = get_trace_flag_for_dbg(TabRec#rETracerConfig.trace_flags),
			
			rpc:call(ErlangNode, dbg, p, [all, TraceflagList]),
			
			%% Get Match Specification
			MatchSpec = create_trace_match_specification(ETracerConfigName),
			
			%% Setup Trace Measure
			set_trace_measure_loop(ErlangNode, TabRec#rETracerConfig.trace_pattern, MatchSpec),
			
			ok;
		{error, Reason} ->
			{error, Reason}
	end.

set_trace_measure_loop(_, [], _) ->
	ok;
set_trace_measure_loop(ErlangNode, [{M,F,A}|T], MatchSpec) ->
	error_logger:info_report(["dbg:tpl/4", {param, {M,F,A, MatchSpec}}]),
	rpc:call(ErlangNode, dbg, tpl, [M,F,A, MatchSpec]),
	set_trace_measure_loop(ErlangNode, T, MatchSpec).

	