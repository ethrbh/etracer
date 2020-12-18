%% Author: ethrbh
%% Created: Jun 22, 2012
%% Description: TODO: Add description to tracer
-module(etracer).

%% --------------------------------------------------------------------
%% Behaviur
%% --------------------------------------------------------------------
-behaviour(wx_object).

%% --------------------------------------------------------------------
%% Includes
%% --------------------------------------------------------------------
-include_lib("wx/include/wx.hrl").
-include_lib("wx/src/wxe.hrl").
-include("../include/etracer.hrl").
-include("../include/commonDB.hrl").

%% --------------------------------------------------------------------
%% WX Exports
%% --------------------------------------------------------------------

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%          wxWidget server exports
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([start/0, start/1, start_link/0, start_link/1, stop/0,
		 format/3, 
		 init/1,  
		 handle_cast/2, handle_call/3, handle_info/2, handle_event/2,
		 terminate/2,  
		 code_change/3]).

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%          Dummy exports
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([getParent/1, getChildren/1, getNotebookTabNames/0, deleteNotebookTab/1]).

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%          wxWidget related exports
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([create_subwindow/3, create_subwindow/4]).

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%          Erlang modules/functions related exports
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([get_modules/1, get_exported_functions/2, get_not_exported_functions/2]).

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%          Misc
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([erlang_term_to_string/1, string_to_erlang_term/1]).
-export([get_next_tracer_port/0, get_tracer_message_queue_size/0]).
-export([print_event/1]).
-export([get_new_line_char/0]).

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%          Database related exports
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([set_etracer_config_record/1, 
		 get_etracer_config_record/1,
		 delete_etracer_config_record/1]).

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%          Database (MNESIA) related exports
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([get_own_database_path/0, make_own_database_dir/0]).
-export([
		 transform_mnesia_table_get_tables/0,   %% Give the list of those MNESIA tables whereon the trahsformation is enabled
		 transform_mnesia_table/1,              %% Trahsforms the old record

		 check_mnesia_transform/0,
		 transform_database/0,
		 transform_database/1
		 ]).


%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------
-record(state, {
				trace_name = "",
				default_panel_color,
				
				tracer_port = ?DEFAULT_TRACER_PORT,
				tracer_message_queue_size = ?DEFAULT_MSG_QUEUE_SIZE,
				win,
				eventWindowId
				}).

%% --------------------------------------------------------------------
%% Defines
%% --------------------------------------------------------------------
-define(SERVER, ?MODULE).

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% @spec start() -> Ref:wxWindow() | {error, Reason}
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start() ->
	start([]).

%% --------------------------------------------------------------------
%% @spec start(Debug) -> Ref:wxWindow() | {error, Reason}
%% Debug	=	term()
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start(Debug) ->
	case catch wx_object:start({local, ?SERVER}, ?MODULE, [Debug], []) of
		Ref when is_record(Ref, wx_ref) ->
			Ref;
		{error,{already_started,_Pid}} ->
			stop(),
			start(Debug);
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% @spec start() -> Ref:wxWindow() | {error, Reason}
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start_link() ->
	start_link([]).

%% --------------------------------------------------------------------
%% @spec start(Debug) -> Ref:wxWindow() | {error, Reason}
%% Debug	=	term()
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start_link(Debug) ->
	case catch wx_object:start_link({local, ?SERVER}, ?MODULE, [Debug], []) of
		Ref when is_record(Ref, wx_ref) ->
			Ref;
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% @spec stop() -> ok | {error, Reason}
%% @doc
%% Stop WX process
%% @end
%% --------------------------------------------------------------------
stop() ->
	case whereis(?SERVER) of
		P when is_pid(P) ->
			case wx_object:call(?SERVER, {stop}, ?WX_OBJECT_CALL_TO) of
				ok ->
					ok;
				{error, Reason} ->
					{error, Reason}
			end;
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% @spec format(Config,Str,Args) -> ok
%% @doc
%% 
%% @end
%% --------------------------------------------------------------------
format(Config,Str,Args) ->
	Log = proplists:get_value(log, Config),
	wxTextCtrl:appendText(Log, io_lib:format(Str, Args)),
	ok.

%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
getParent(Obj) ->
	case whereis(?SERVER) of
		P when is_pid(P) ->
			wx_object:cast(?SERVER, {getParent, Obj});
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
getChildren(Obj) ->
	case whereis(?SERVER) of
		P when is_pid(P) ->
			wx_object:cast(?SERVER, {getChildren, Obj});
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% Give the list of TABs of Notebook
%% Input:	-
%% Output:	{ok, L} | {error, Reason}
%% --------------------------------------------------------------------
getNotebookTabNames() ->
	case whereis(?SERVER) of
		P when is_pid(P) ->
			case catch wx_object:call(?SERVER, {getNotebookTabNames}, ?WX_OBJECT_CALL_TO) of
				{ok, L} ->
					{ok, L};
				{error, Reason} ->
					{error, Reason}
			end;
		Error ->
			{error, Error}
	end.

%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
deleteNotebookTab(TabId) when is_integer(TabId) ->
	case whereis(?SERVER) of
		P when is_pid(P) ->
			case catch wx_object:call(?SERVER, {deleteNotebookTab, TabId}, ?WX_OBJECT_CALL_TO) of
				{ok, L} ->
					{ok, L};
				{error, Reason} ->
					{error, Reason}
			end;
		Error ->
			{error, Error}
	end.

%% --------------------------------------------------------------------
%% @spec create_subwindow(Parent, BoxLabel, Funs) -> {Panel, Ctrls, Sizer}
%% Panel	=	wxWindow()
%% Ctrls	=	list of created object ids, example list of wxWindow()
%% Sizer	=	id of sizer where the window belongs
%% 
%% @doc
%% Create a sub-window on the parent
%% @end
%% --------------------------------------------------------------------
create_subwindow(Parent, BoxLabel, Funs) ->
	
	Panel = wxPanel:new(Parent),
	
	%%error_logger:info_report(["create_subwindow/3", {parent, Parent}, {boxLabel, BoxLabel}, {funs, Funs}, {module, ?MODULE}, {line, ?LINE}]),
	
	Sz = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, BoxLabel}]),
	wxPanel:setSizer(Panel, Sz),
	Ctrls = [Fun(Panel) || Fun <- Funs],
	[wxSizer:add(Sz, Ctrl, [{proportion, 1}, {flag, ?wxEXPAND}]) || {Ctrl, _} <- Ctrls],
	
	{Panel, Ctrls, Sz}.

%% --------------------------------------------------------------------
%% @spec create_subwindow(Parent, BoxLabel, Funs, Sizer) -> {Panel, Ctrls, Sizer}
%% Panel	=	wxWindow()
%% Ctrls	=	list of {created_object_id, Info}, [{Obj,Info}, {...}, ...]
%% Sizer	=	id of sizer where the window belongs
%% 
%% @doc
%% Create a sub-window on the parent
%% @end
%% --------------------------------------------------------------------
create_subwindow(Parent, _BoxLabel, Funs, Sizer) ->
	Panel = wxPanel:new(Parent),
	
	%%error_logger:info_report(["create_subwindow/4", {parent, Parent}, {boxLabel, BoxLabel}, {funs, Funs}, {sizer, Sizer}, {module, ?MODULE}, {line, ?LINE}]),
	
	%%wxPanel:setSizer(Panel, Sizer),
	Ctrls = [Fun(Panel) || Fun <- Funs],
	[wxSizer:add(Sizer, Ctrl, [{proportion, 1}, {flag, ?wxEXPAND}]) || {Ctrl, _} <- Ctrls],
	
	{Panel, Ctrls, Sizer}.

%% --------------------------------------------------------------------
%% @spec get_modules(ErlangNode) -> {ok, List} | {error, Reason}
%% List	=	[Mod,...], where Mod is an atom
%% 
%% @doc
%% This function will to give all tracaiable modules with all functions.
%% @end
%%---------------------------------------------------------------------
get_modules(ErlangNode)->
	%% example:
	%% [{io,"d:/ethrbh/erlang/lib/stdlib-1.12/ebin/io.beam"},
	%%   {erl_distribution,"d:\\ethrbh\\erlang/lib/kernel-2.9/ebin/e"},
	%%   {edlin,"d:/ethrbh/erlang/lib/stdlib-1.12/ebin/edlin.beam"},do_nothing,...]
	
	case catch rpc:call(ErlangNode,code,all_loaded,[]) of
		{'EXIT',Reason}  ->
			%% Error occured. The ErlangNode is not alive
			{error, {'EXIT',Reason}};
		
		{badrpc,nodedown} ->
			%% Erlang Node is down
			{error, {badrpc,nodedown}};
		
		_-> %% ErlangNode is alive
			{ok, get_modules_loop(rpc:call(ErlangNode, code, all_loaded, []), [])}
	end.

get_modules_loop([],ModuleList)->
	lists:sort(ModuleList);
get_modules_loop([ModuleListTempHead | ModuleListTempTail],ModuleList)->
	{ModuleName,_Path} = ModuleListTempHead,
	case ModuleList == [] of
		true ->
			get_modules_loop(ModuleListTempTail,[ModuleName]);
		false ->
			get_modules_loop(ModuleListTempTail,[ModuleName | ModuleList])
	end.

%%---------------------------------------------------------------------
%% @spec get_exported_functions(ErlangNode, ModuleName) -> {ok, List} | {error, Reason}
%% ErlangNode	=	atom()
%% ModuleName	=	atom()
%% List			=	list(), list of tuple, [{Func, Arity}, ...]
%% 
%% @doc
%% This function will to give the EXPORTED functions of the Module
%% @end
%%---------------------------------------------------------------------
get_exported_functions(ErlangNode, ModuleName)->
	%% Check the 1st char of ModuleName
	case catch string:substr(atom_to_list(ModuleName), 1, 1) of
			{'EXIT', Reason} ->
				%% Error occured...
				{error, {'EXIT', Reason}};
			"*" ->
				%% The 1st char is *
				{ok, []};
			_->
				case catch rpc:call(ErlangNode, ModuleName, module_info, []) of
					{'EXIT', Reason} ->
						%% Error occured. The ErlangNode is not alive.
						{error, {'EXIT', Reason}};
					{badrpc, Reason} ->
						{error, {badrpc, Reason}};
					_->
						case catch lists:keysearch(exports, 1, rpc:call(ErlangNode, ModuleName, module_info, [])) of
							{'EXIT', Reason}  ->
								{error, {'EXIT', Reason}};
							{value, {exports, Exported}} ->
								{ok, Exported};
							Reason ->
								{error, Reason}
						end
				end
		end.

%%---------------------------------------------------------------------
%% @spec get_not_exported_functions(ErlangNode, ModuleName) -> {ok, List} | {error, Reason}
%% ErlangNode	=	atom()
%% ModuleName	=	atom()
%% List			=	list(), list of tuple, [{Func, Arity}, ...]
%%
%% @doc
%% This function will to give the NOT EXPORTED functions of the Module
%% @end
%%---------------------------------------------------------------------
get_not_exported_functions(ErlangNode, ModuleName) ->
	case catch string:substr(atom_to_list(ModuleName), 1, 1) of
		{'EXIT', Reason}  ->
			{error, {'EXIT', Reason}};
		"*"  ->
			{ok, []};
		_-> 
			case catch rpc:call(ErlangNode, code, which, [ModuleName]) of
				{'EXIT',Reason}  ->
					%% Error occured. The ErlangNode is not alive
					{error, {'EXIT', Reason}};
				{badrpc,Reason} ->
					{error, {badrpc,Reason}};
				non_existing ->
					{error, non_existing};
				BeamPath -> 
					case catch rpc:call(ErlangNode, beam_lib, chunks, [BeamPath, [locals]]) of
						{'EXIT', Reason}->
							%% Error occured. The ErlangNode is not alive
							{error, {'EXIT', Reason}};
						{badrpc, Reason} ->
							{error, {badrpc,Reason}};
						{ok,{_,[{locals, LocalFunctions}]}} ->
							{ok, LocalFunctions};
						Reason ->
							{error, Reason}
					end
			end
	end.
%% --------------------------------------------------------------------
%% @spec erlang_term_to_string(Term::term()) -> {ok, String::string()} | {error, Reason}
%% @doc
%% Convert erlang term() to string<br/>
%% Input:<bb/>
%%      Term	=	[{a,b},{r,b,7,8},...]<br/>
%% Output:<bb/>
%%      {ok, String}  =	"[{a,b},{r,b,7,8},...]" | {error, Reason}
%% @end
%% --------------------------------------------------------------------
erlang_term_to_string(Term)->
    case catch lists:flatten(io_lib:format("~p",[Term])) of
        {'EXIT',Reason}->
            %% Error occured...
			io:format("ERROR - Error occured at calling erlang_term_to_string/1. Module: ~p, Line: ~p, Reason: ~p~n", [?MODULE, ?LINE, Reason]),
            {error, "ERROR - Error occured at calling erlang_term_to_string/1."};
        List when is_list(List)->
            {ok, List};
        Reason ->
			io:format("ERROR - Error occured at calling erlang_term_to_string/1. Module: ~p, Line: ~p, Reason: ~p~n", [?MODULE, ?LINE, Reason]),
			{error, "ERROR - Error occured at calling erlang_term_to_string/1."}
    end.

%%-----------------------------------------------------------------------------------------
%% @spec string_to_erlang_term(String) -> {ok, term()} | {error, Reason}
%% @doc
%% Convert string to erlang term
%% @end
%%-----------------------------------------------------------------------------------------
string_to_erlang_term(String) when is_list(String) ->
	case String of
		""->[];
		_-> %% This is a non empty string
			case catch erl_scan:string(String ++ ".") of
				{'EXIT', Reason} ->
					{error, {'EXIT', Reason}};
				{ok, T, _} ->
					case catch erl_parse:parse_term(T) of
						{ok, Term} ->
							{ok, Term};
						Reason ->
							{error, Reason}
					end;
				Reason ->
					{error, Reason}
			end
	end;
string_to_erlang_term(Other) ->
	Other.

%% --------------------------------------------------------------------
%% @spec get_next_tracer_port() -> {ok, Port} | {error, Reason}
%% @doc
%% Give the next Tracer Port can be use for setting up DBG trace towards the external node.
%% @end
%% --------------------------------------------------------------------
get_next_tracer_port() ->
	case catch wx_object:call(?SERVER, {get_next_tracer_port}, ?WX_OBJECT_CALL_TO) of
		{ok, Port} ->
			{ok, Port};
		{error, Reason} ->
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% @spec get_tracer_message_queue_size() -> {ok, MsgQueueSize} | {error, Reason}
%% @doc
%% Give the Message queue size for DBG trace
%% @end
%% --------------------------------------------------------------------
get_tracer_message_queue_size() ->
	case catch wx_object:call(?SERVER, {get_tracer_message_queue_size}, ?WX_OBJECT_CALL_TO) of
		{ok, MsgQueueSize} ->
			{ok, MsgQueueSize};
		{error, Reason} ->
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% @spec print_event(Event) -> ok
%% Event	=	string()
%% @doc
%% Print event into Event Window
%% @end
%% --------------------------------------------------------------------
print_event(Event) ->
	?SERVER ! {print_event, Event},
	ok.

%% --------------------------------------------------------------------
%% @spec get_new_line_char() -> NewLineChar
%% NewLineChar	=	string()
%% @doc
%% Give the new line char used in the OS where ETracer is running.
%% @end
%% --------------------------------------------------------------------
get_new_line_char() ->
	NewLineChar = case os:type() of
					  {unix, _} ->
						  %% Unix/Linux OS
						  "\n";
					  {win32, _} ->
						  %% Windows OS
						  "\r\n"
				  end,
	NewLineChar.

%% --------------------------------------------------------------------
%% @spec set_etracer_config_record(Rec) -> ok | {error, Reason}
%% Rec		=	#rETracerConfig{}
%% Reason	=	term()
%% @doc
%% Set the ETracer record in MNESIA
%% @end
%% --------------------------------------------------------------------
set_etracer_config_record(Rec) when is_record(Rec, rETracerConfig) ->
	case commonDB:update_mnesia_table_record(?ETRACER_CONFIG_TABLE, Rec) of
		ok ->
			ok;
		{nok, Reason} ->
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% @spec get_etracer_config_record(Key) -> {ok, Rec} | {error, Reason}
%% Key		=	key in #rETracerConfig{} | #wx_ref{}
%% Reason	=	term()
%% @doc
%% Get the ETracer record in MNESIA
%% @end
%% --------------------------------------------------------------------
get_etracer_config_record(Key) when is_list(Key) ->
	case commonDB:get_table_record(?ETRACER_CONFIG_TABLE, Key) of
		[Rec] when is_record(Rec, rETracerConfig) ->
			{ok, Rec};
		Reason ->
			{error, Reason}
	end;
get_etracer_config_record(Obj) when is_record(Obj, wx_ref) ->
	%% Find the TAB record by Obj Id.
	get_etracer_tab_record_loop(ets:first(?ETRACER_CONFIG_TABLE), Obj, {error, "TAB does not found"}).

get_etracer_tab_record_loop('$end_of_table', _Obj, Result) ->
	Result;
get_etracer_tab_record_loop(Key, Obj, Result) ->
	case commonDB:get_table_record(?ETRACER_CONFIG_TABLE, Key) of
		[Rec] when is_record(Rec, rETracerConfig) ->
			case lists:keysearch(Obj, 2, Rec#rETracerConfig.object_list) of
				{value, _} ->
					{ok, Rec};
				_->	get_etracer_tab_record_loop(ets:next(?ETRACER_CONFIG_TABLE, Key), Obj, Result)
			end;
		_->	get_etracer_tab_record_loop(ets:next(?ETRACER_CONFIG_TABLE, Key), Obj, Result)
	end.

%% --------------------------------------------------------------------
%% @spec delete_etracer_config_record(Input) -> ok | {error, Reason}
%% Input	=	Key as a string | Rec as #rETracerConfig{}
%% @doc
%% Delete record in MNESIA
%% @end
%% --------------------------------------------------------------------
delete_etracer_config_record(Rec) when is_record(Rec, rETracerConfig) ->
	delete_etracer_config_record(Rec#rETracerConfig.name);
delete_etracer_config_record(Key) when is_list(Key) ->
	case commonDB:delete_mnesia_table_record(?ETRACER_CONFIG_TABLE, Key) of
		ok ->
			ok;
		{nok, Reason} ->
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% Give the Database path of ETracer. The DB folder located under
%% the ETracer folder
%% Input:	-
%% Output:  Path	-	string
%% --------------------------------------------------------------------
get_own_database_path()->
	{ok,CWD} = file:get_cwd(),
	
	PathSeparator = case os:type() of
						{unix, _} ->
							%% Unix/Linux OS
							"/";
						{win32, _} ->
							%% Windows OS
							"/"
					end,
	lists:concat([CWD,PathSeparator,"Database",PathSeparator]).

%% --------------------------------------------------------------------
%% @spec make_own_database_dir() -> ok | {error, Reason}
%% @doc
%% Create DB dir if it is not yet done.
%% @end
%% --------------------------------------------------------------------
make_own_database_dir() ->
	DBPath = get_own_database_path(),
	case file:make_dir(DBPath) of
		ok ->
			ok;
		{error, eexist} ->
			%% Already done
			ok;
		{error, Reason} ->
			{error, Reason}
	end.

%%-----------------------------------------------------------------------------------------
%% Give the list of those MNESIA tables whereon the transformation is enabled
%% Input:
%%      -
%% Output:
%%      L   -   list, eq: [{TabName,{NewRecName,NewAttrs}}, ...]
%%-----------------------------------------------------------------------------------------
transform_mnesia_table_get_tables()->
    [
	{?ETRACER_CONFIG_TABLE, {rETracerConfig, record_info(fields,rETracerConfig)}}
    ].
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Transforms the old record
%%-----------------------------------------------------------------------------------------
transform_mnesia_table({What,Rec})->
    case element(1,Rec) of
		rETracerConfig ->
			do_transform_mnesia_table({rETracerConfig, {What,Rec}})
    end.

%%% What: rec_attributes | rec, what is the record: record attributes (with recname) or the record itself
do_transform_mnesia_table({RecName, {What,OldRec}}) ->
    case RecName of
		rETracerConfig ->
			transform_mnesia_table_settings_table({What,OldRec})
	end.

transform_mnesia_table_settings_table({What,OldRec}) ->
    %% current record version
    #rETracerConfig{vsn_0 = {val,CurrVsn}} = #rETracerConfig{},
    
    %% 3rd parameter is the version field
    case {What,element(3, OldRec)} of
        %%----------------------------------------------------------------
        %% the current version => no transformation is needed
        {rec_attributes,CurrVsn} ->
            %% called to check if transformation is needed or not
            {ok,not_needed};
        {rec,{val,CurrVsn}} ->
            %% This is the record to be converted. No conversion needed, return the input
            {ok,OldRec};
        %% END (the current version)
        %%----------------------------------------------------------------
        
        %% END Check unsupported transform
        %%----------------------------------------------------------------

        %%----------------------------------------------------------------
        %% Legacy record transform
        {rec,_} -> 
            %% build the transform helper table if needed
            {ok,#rETracerConfig{}};
        Unexp -> {nok,{unexpected_case,Unexp}}
    end.
%%-----------------------------------------------------------------------------------------
%% Mnesia transform functions
%%-----------------------------------------------------------------------------------------
%% list of modules that support mnesia table transform. extend the list if needed.
check_mnesia_transform()  ->
    mnesia_transformer:check_mnesia_transform(?MODULE,?MNESIA_TRANSFORM_MODULES).
            
transform_database() ->
    mnesia_transformer:transform_database(?MODULE,[dummy],not_sure).

transform_database(Mode) ->
    %% Init MNESIA tables
    commonDB:init_mnesia_tables(),
    timer:sleep(300), %% wait info report to be completed
    mnesia_transformer:transform_database(?MODULE,?MNESIA_TRANSFORM_MODULES,Mode).


%% --------------------------------------------------------------------
%% @spec init(Options) -> {Frame, #state{}}
%% Options	=	{debug, list() | atom()}
%% @doc
%% Init WX server
%% @end
%% --------------------------------------------------------------------
init(Options) ->
	
	%% Setup DB before doing anyting else
	case make_own_database_dir() of
		{error, Reason} ->
			error_logger:error_report(["Could not create DB dir. Exit.", {reason, Reason}, {module, ?MODULE}, {line, ?LINE}]),
			ok;
		ok ->
			%% ---------------------------------
			%% -- Init DB --
			%% ---------------------------------
			commonDB:start(?RECORD_LIST),
			
			%% Init ETS and MNESIA tables
			commonDB:init_mnesia_tables(get_own_database_path(), ?mnesia_table_list),
			
			%% Check if mnesia transformation is needed
			check_mnesia_transform(),
			
			
			%% ---------------------------------
			%% Starting GUI...
			%% ---------------------------------
			wx:new(Options),
			process_flag(trap_exit, true),
			
			%% Create Main Frame object
			Frame = wxFrame:new(wx:null(), ?wxID_ANY, ?MAIN_TITLE++"-"++?TOOL_VERSION, [{size,?MAIN_WINDOW_SIZE}]),
			
			%% Create Menu Bar object
			MB = wxMenuBar:new(),
			
			%% Create File Menu objects in Menu Bar
			File = wxMenu:new([]),
			wxMenuBar:append(MB, File, "&File"),
			%%wxMenu:append(File, ?WX_ETRACER_MENU_ID_SAVE_SETTINGS, "Save settings"),
			%%wxMenu:append(File, ?wxID_EXIT, "Load settings"),
			wxMenu:append(File, ?wxID_EXIT, "Exit"),
			
			%% Create Help menu
			%%Help = wxMenu:new([]),
			%%wxMenuBar:append(MB, Help, "&Help"),
			
			wxFrame:setMenuBar(Frame, MB),
			
			wxFrame:connect(Frame, command_menu_selected),
			
			_SB = wxFrame:createStatusBar(Frame,[]),
			
			%% --------------------------------------------------------------------
			%% Do not touch this part!!
			%% --------------------------------------------------------------------
			Panel = wxPanel:new(Frame, []),
			DefaultPanelColor = wxPanel:getBackgroundColour(Panel),
			
			Sizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, ""}]),
			Splitter = wxSplitterWindow:new(Panel, [{style, ?wxSP_BORDER}]),
			
			NewTraceSizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, "Enter New Trace Name"}]),
			
			wxSizer:add(Sizer, NewTraceSizer, [{flag, ?wxEXPAND}]),
			TraceNameTextCtrl = wxTextCtrl:new(Panel, ?ENTRY_ID_NEWTRACE, [{value, ""}, {style, ?wxDEFAULT}]),
			wxSizer:add(NewTraceSizer, TraceNameTextCtrl, [{flag, ?wxEXPAND}]),
			wxTextCtrl:connect(TraceNameTextCtrl, command_text_updated),
			
			NewTraceButton = wxButton:new(Panel, ?BTN_ID_NEWTRACE, [{label, "Create New Trace"}]),
			wxSizer:add(NewTraceSizer, NewTraceButton, [{flag, ?wxEXPAND}]),
			wxButton:connect(NewTraceButton, command_button_clicked),
			
			%% --------------------------------------------------------------------
			%% Do not touch this part END
			%% --------------------------------------------------------------------
			
			TracePanelFun = fun(Parent) ->
									MainSizer2 = wxStaticBoxSizer:new(?wxVERTICAL, Parent, [{label, ""}]),
									
									_Sizer1 = wxBoxSizer:new(?wxHORIZONTAL),
									
									Notebook = enotebook:start([{parent, Parent},  {color, DefaultPanelColor}]),
									
									wxSizer:add(MainSizer2, Notebook, [{proportion, 1},
																	   {flag, ?wxEXPAND}]),
									wxPanel:setSizer(Panel, MainSizer2),
									
									{Notebook, []}
							end,
			{TracePanel, [{Notebook, _Info}|_], _} = create_subwindow(Splitter, "Trace", [TracePanelFun]),
			
			%% Create default Trace TAB
			%%_TraceTab = enotebook:create_tab("Default", [{parent, Notebook}, {color, DefaultPanelColor}, {name, "Default"}]),
			
			%% Load all Tracer TAB. Check MNESIA for these.
			[begin
				 enotebook:create_tab(Rec#rETracerConfig.name, [{parent, Notebook}, {color, DefaultPanelColor}, {name, Rec#rETracerConfig.name}, {erlangNode, Rec#rETracerConfig.erlang_node}, {erlangNodeCookie, Rec#rETracerConfig.erlang_node_cookie}])
			 end || Rec <- ets:tab2list(?ETRACER_CONFIG_TABLE)],

			%% Event Panel
			EventPanel = wxPanel:new(Splitter, []),
			EventPanelSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, EventPanel, [{label, "Events"}]),
			EventPanelCtrl = wxTextCtrl:new(EventPanel, ?wxID_ANY, [{value, ""}, {style, ?wxTE_DONTWRAP bor ?wxTE_MULTILINE bor ?wxTE_READONLY}]),
			wxSizer:add(EventPanelSizer, EventPanelCtrl, [{flag, ?wxEXPAND}, {proportion, 1}]),
			wxPanel:setSizer(EventPanel, EventPanelSizer),
			
			%% --------------------------------------------------------------------
			%% Do not touch this part!!
			%% --------------------------------------------------------------------
			wxSplitterWindow:splitHorizontally(Splitter, TracePanel, EventPanel, [{sashPosition,-100}]),
			wxSplitterWindow:setSashGravity(Splitter, 1.0),
			wxSplitterWindow:setMinimumPaneSize(Splitter, 50),
			wxSizer:add(Sizer, Splitter, [{flag, ?wxEXPAND}, {proportion, 1}]),
			wxPanel:setSizer(Panel, Sizer),
			%% --------------------------------------------------------------------
			%% Do not touch this part END
			%% --------------------------------------------------------------------
			
			State = #state{win = Frame,
						   eventWindowId = EventPanelCtrl,
						   default_panel_color = DefaultPanelColor},
			
			wxFrame:show(Frame),
			
			{Frame, State}
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
	enotebook:stop(),
	{stop, normal, ok, State};

handle_call({get_next_tracer_port}, _From, State) ->
	Port = State#state.tracer_port,
	{reply, {ok, Port}, State#state{tracer_port = Port+1}};
	
handle_call({get_tracer_message_queue_size}, _From, State) ->
	{reply, {ok, State#state.tracer_message_queue_size}, State};

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
handle_cast({getParent, Obj}, State)->
	getParent_int(Obj),
	{noreply, State};

handle_cast({getChildren, Obj}, State) ->
	getChildren_int(Obj),
	{noreply, State};

handle_cast(_Msg, State) ->
	%%error_logger:info_report(["handle_cast", {module, ?MODULE}, {line, ?LINE}, {msg, _Msg}]),
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({print_event, Event}, State) ->
	print_event_int(State#state.eventWindowId, Event),
	{noreply, State};

handle_info(_Info, State) ->
	%%error_logger:info_report(["handle_info", {module, ?MODULE}, {line, ?LINE}, {info, _Info}]),
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_event/2
%% Description: %% Async Events are handled in handle_event as in handle_info
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_event(_WXEvent = #wx{id = Id,
						   event = #wxCommand{type = command_menu_selected}},
			 State)->
	
	%%error_logger:info_report(["Event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
	
	case Id of
		?WX_ETRACER_MENU_ID_SAVE_SETTINGS ->
			%% Save ETracer settings into MNESIA
			{noreply, State};
		?wxID_EXIT ->
			ExitString = "Do you want to exit?",
			PressedButton = wxMessageDialog:showModal(wxMessageDialog:new(State#state.win, ExitString,
																		  [{style,
																			?wxYES_NO bor ?wxICON_INFORMATION bor ?wxSTAY_ON_TOP},
																		   {caption, "Exit"}])),
			case PressedButton of
				?wxID_NO ->
					{noreply, State};
				?wxID_YES ->
					{stop, normal, State}
			end;
		_->
			%%error_logger:info_report(["Unexpected event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
			{noreply, State}
	end;

handle_event(#wx{id = Id, 
				 obj = Obj,
				 event = #wxCommand{type = command_text_updated}}, State) ->
	%% Event received from wxTextCtrl object. Read the text from entry.
	Text = wxTextCtrl:getValue(Obj),
	
	case Id of
		?ENTRY_ID_NEWTRACE ->
			%% New Trace name
			{noreply, State#state{trace_name = Text}};
		_-> {noreply, State}
	end;

handle_event(_WXEvent = #wx{id = Id, 
						   obj = _Obj,
						   event = #wxCommand{type = command_button_clicked}}, State) ->
	%%error_logger:info_report(["Event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
	case Id of
		?BTN_ID_NEWTRACE ->
			%% Create New Trace TAB
			ETracerConfigName = State#state.trace_name,
			
			case ETracerConfigName of
				[] ->
					%% Invalid. Must set any name.
					PressedButton = wxMessageDialog:showModal(wxMessageDialog:new(State#state.win, "Please set any name",
																				  [{style, ?wxOK bor ?wxICON_ERROR bor ?wxSTAY_ON_TOP},
																				   {caption, "Error when createing new Trace"}])),
					case PressedButton of
						_->	{noreply, State}
					end;
				_->
					%%Notebook = State#state.trace_panel_notebook_id,
					
					%% Validate Trace Name
					case enotebook:create_tab(ETracerConfigName, [{color, State#state.default_panel_color}]) of
						TraceTab when is_record(TraceTab, wx_ref) ->
							{noreply, State};
						{error, Reason} ->
							%% Trace Name is already exist. Please use an other name
							PressedButton = wxMessageDialog:showModal(wxMessageDialog:new(State#state.win, Reason,
																						  [{style, ?wxOK bor ?wxICON_ERROR bor ?wxSTAY_ON_TOP},
																						   {caption, "Error when createing new Trace"}])),
							case PressedButton of
								_->	{noreply, State}
							end;
						
						_->	%% Error occured when fetching TABs
							{noreply, State}
					end
				end;
		_->	%%error_logger:info_report(["Unexpected event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
			{noreply, State}
	end;

handle_event(_WXEvent, State) ->
	%%error_logger:info_report(["Unexpected event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	%%error_logger:info_report(["terminate received", {module, ?MODULE}, {line, ?LINE}, {reason, _Reason}]),
	wx:destroy().

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process rSTATE when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.


%% --------------------------------------------------------------------
%% Local Functions
%% --------------------------------------------------------------------

%% deleteNotebookTab_int(Notebook, TabId) ->
%% 	case catch wxAuiNotebook:deletePage(Notebook, TabId) of
%% 		true ->
%% 			true;
%% 		Else ->
%% 			{error, Else}
%% 	end.

getParent_int(Obj) ->
	Mod = Obj#wx_ref.type,
	getParent_int(Mod, Obj).

getParent_int(Mod, Obj) ->
	case catch Mod:getParent(Obj) of
		Parent when is_record(Parent, wx_ref) ->
			%%error_logger:info_report(["Get Parent", {mod, Mod}, {obj, Obj}, {parent, Parent}]),
			getParent_int(Parent#wx_ref.type, Parent);
		Error ->
			%%error_logger:info_report(["Get Parent", {mod, Mod}, {obj, Obj}, {error, Error}]),
			{error, Error}
	end.

getChildren_int(Obj) ->
	case catch wxWindow:getChildren(Obj) of
		L when is_list(L) ->
			%%error_logger:info_report(["Get Children", {obj, Obj}, {childrenList, L}]),
			L;
		_Error ->
			%%error_logger:info_report(["Get Children", {obj, Obj}, {error, Error}]),
			ok
	end.

%% --------------------------------------------------------------------
%% Print new event in the Event Window
%% Input:
%%		EventWindowId	:	object id
%%		Event			:	string
%% Output:
%%		ok 
%% --------------------------------------------------------------------
print_event_int(EventWindowId, Event) ->
	wxTextCtrl:appendText(EventWindowId, Event++"\n"),
	ok.