%%% -------------------------------------------------------------------
%%% Author  : ETHRBH
%%% Description :
%%%
%%% Created : Jun 24, 2012
%%% -------------------------------------------------------------------
-module(etracer_tester).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("../include/commonDB.hrl").
-include("../include/etracer.hrl").

%% --------------------------------------------------------------------
%% Define
%% --------------------------------------------------------------------


%% --------------------------------------------------------------------
%% External exports
-export([start/3, stop/1]).

-export([test/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {tref}).

%% ====================================================================
%% External functions
%% ====================================================================
start(TesterName, TraceName, TickInterval) ->
	case whereis(TesterName) of
		P when is_pid(P) ->
			{error, already_started};
		_->	case catch gen_server:start({local, TesterName}, ?MODULE, [{TraceName, TickInterval}], []) of
				{ok, Pid} ->
					{ok, Pid};
				{error, Reason} ->
					{error, Reason};
				Reason ->
					{error, Reason}
			end
	end.

stop(TesterName) ->
	case whereis(TesterName) of
		P when is_pid(P) ->
			P ! {stop},
			ok;
		_->	{error, tester_is_not_running}
	end.

test() ->
	commonDB:start(?RECORD_LIST),
	A = #rTraceFlags{},
	{#rTraceFlags.call, A, commonDB:get_record_element_pos(call, rTraceFlags)}.

%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([{TraceName, TickInterval}]) ->
	self() ! {start_test, TraceName, TickInterval},
    {ok, #state{}}.

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
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({start_test, TraceName, TickInterval}, State) ->
	{ok, TRef} = timer:send_interval(TickInterval, self(), {start_test_tick, TraceName}),
	{noreply, State#state{tref = TRef}};
handle_info({start_test_tick, TraceName}, State) ->
	enotebook:appendTraceLog(TraceName, "Ez egy oltari nagy test szoveg\r\n"),
	{noreply, State};
handle_info({stop}, State) ->
	timer:cancel(State#state.tref),
	{stop, normal, State};
handle_info(Info, State) ->
	error_logger:info_report(["Unexpected message received", {msg, Info}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
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

