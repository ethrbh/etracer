%% Author: ethrbh
%% Created: Jun 22, 2012
%% Description: TODO: Add description to tracer
-module(enotebook).

%% --------------------------------------------------------------------
%% Behaviour
%% --------------------------------------------------------------------
-behaviour(wx_object).

%% --------------------------------------------------------------------
%% Includes
%% --------------------------------------------------------------------
-include_lib("wx/include/wx.hrl").
-include_lib("wx/src/wxe.hrl").
-include("../include/etracer.hrl").

%% --------------------------------------------------------------------
%% WX Exports
%% --------------------------------------------------------------------
-export([start/0, start/1, start_link/0, start_link/1, stop/0,
		 format/3, 
		 init/1,  
		 handle_cast/2, handle_call/3, handle_info/2, handle_event/2,
		 terminate/2,  
		 code_change/3]).

-export([create_tab/2]).

%% --------------------------------------------------------------------
%% Exported functions just for test purpose
%% --------------------------------------------------------------------
-export([appendTraceLog/3]).

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------
%% -record(rNOTEBOOK_TAB, {
%% 						%% string, name of the TAB
%% 						name,
%% 						
%% 						%% the main panel, wxWindow()
%% 						tab_obj,
%% 						
%% 						%% List of tuple of used Wx Objects on TAB
%% 						%% example: [{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.trace_log_window_id), Value}, {...}, ...]
%% 						object_list,
%% 						
%% 						%% atom()
%% 						erlang_node = ?DEFAULT_ERLANG_NODE,
%% 						erlang_node_cookie = ?DEFAULT_ERLANG_NODE_COOKIE
%% 					   }).

-record(state, {
				parent,		%% Parent Obj ID
				config,		%% list of tuple
				
				notebook_id,%% Obj ID of the NoteBook towhere the TAB placed
				
				%% Integer id of selected TAB.
				%% notebook_id and this need to get wxWindow() Obj id of TAB
				%% wxAuiNotebook:getPage/2
				selected_tab_number,
				selected_tab_name
				
				%%undeterminate_gauge
			   }).

%% -record(gauge, {obj,
%% 				value,
%% 				timer,
%% 				range
%% 			   }).

%% --------------------------------------------------------------------
%% Defines
%% --------------------------------------------------------------------
-define(SERVER, ?MODULE).

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% @spec start() -> {ok, Pid} | {error, Reason}
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start() ->
	start([]).

%% --------------------------------------------------------------------
%% @spec start(Config) -> {ok, Pid} | {error, Reason}
%% Debug	=	term()
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start(Config) ->
	case catch wx_object:start({local, ?SERVER}, ?MODULE, Config, []) of
		Ref when is_record(Ref, wx_ref) ->
			Ref;
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
%% @spec start(Config) -> Ref:wxWindow() | {error, Reason}
%% Config	=	term()
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start_link(Config) ->
	case catch wx_object:start_link({local, ?SERVER}, ?MODULE, Config, []) of
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
%% @spec create_tab(ETracerConfigName, Config) -> TabId:wxWindow() | {error, Reason}
%% @doc
%% Create a new TAB into Notebook object
%% @end
%% --------------------------------------------------------------------
create_tab(ETracerConfigName, Config) ->
	case whereis(?SERVER) of
		Pid when is_pid(Pid) ->
			case catch gen_server:call(?SERVER, {create_tab, ETracerConfigName, Config}, ?WX_OBJECT_CALL_TO) of
				{ok, TabId} when is_record(TabId, wx_ref) ->
					TabId;
				{error, Reason} ->
					{error, Reason}
			end;
		_->	{error, "Server is not alive"}
	end.

%% --------------------------------------------------------------------
%% @spec appendTraceLog(Destionation, ETracerConfigName, Text) -> ok | {error, Reason}
%% --------------------------------------------------------------------
appendTraceLog(Destionation, ETracerConfigName, Text) ->
	case whereis(?SERVER) of
		Pid when is_pid(Pid) ->
			case catch gen_server:call(?SERVER, {appendTraceLog, Destionation, ETracerConfigName, Text}, ?WX_OBJECT_CALL_TO) of
				ok ->
					ok;
				{error, Reason} ->
					{error, Reason}
			end;
		_->	{error, "Server is not alive"}
	end.

%% --------------------------------------------------------------------
%% @spec init(Config) -> {Frame, #state{}}
%% Config	=	list of tuple
%% @doc
%% Init WX server
%% @end
%% --------------------------------------------------------------------
init(Config) ->
	Parent = proplists:get_value(parent, Config),
	
	Style = (0
				 bor ?wxAUI_NB_DEFAULT_STYLE
				 bor ?wxAUI_NB_TOP
				 bor ?wxAUI_NB_WINDOWLIST_BUTTON
				 bor ?wxAUI_NB_CLOSE_ON_ACTIVE_TAB
				 bor ?wxAUI_NB_TAB_MOVE
				 bor ?wxAUI_NB_SCROLL_BUTTONS
                 bor ?wxSUNKEN_BORDER
			),
	
	Notebook = wxAuiNotebook:new(Parent, [{style, Style}]),
	
	wxAuiNotebook:connect(Notebook, command_button_clicked),
	wxAuiNotebook:connect(Notebook, command_auinotebook_page_close, [{skip, false}]),
	wxAuiNotebook:connect(Notebook, command_auinotebook_page_changed),
	
	{Notebook, #state{config = Config, 
					  parent = Parent, 
					  notebook_id = Notebook}}.

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
handle_call({create_tab, ETracerConfigName, Config}, _From, State) ->
	
	Parent = State#state.notebook_id,
	
	%% Validate ETracerConfigName first
	case getNotebookTabNames_int(Parent) of
		{ok, List} ->
			case lists:member(ETracerConfigName, List) of
				true ->
					{reply, {error, "Trace Name is already exist. Please use an other name"} ,State};
				_->
					
					DefaultPanelColor = proplists:get_value(color, Config),
					
					Panel = wxPanel:new(Parent, [{size, {100, 100}}]),
					wxPanel:setBackgroundColour(Panel, DefaultPanelColor),
					
					%% Setup sizers
					MainSizer = wxBoxSizer:new(?wxVERTICAL),
					Sizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, ""}]),
					
					Splitter = wxSplitterWindow:new(Panel, []),
					
					ErlangNode = case proplists:get_value(erlangNode, Config) of
									 undefined ->
										 %% Use default Erlang node
										 ?DEFAULT_ERLANG_NODE;
									 EN ->
										 EN
								 end,
					ErlangNodeCookie = case proplists:get_value(erlangNodeCookie, Config) of
										   undefined ->
											   %% Use default cookie
											   ?DEFAULT_ERLANG_NODE_COOKIE;
										   Cookie ->
											   Cookie
									   end,
					
					{TraceSettingsPanel, [{_SubPanel, Info} | _], _TraceSettingPanelSizer} = etracer:create_subwindow(Splitter, "Trace Settings", [create_trace_settings_panel(ErlangNode, ErlangNodeCookie)]),
					%%error_logger:info_report(["TraceSettingsPanel created", {traceSettingsPanel, TraceSettingsPanel}, {children, wxWindow:getChildren(TraceSettingsPanel)}, {info, Info}]),
					
					{TracePanel, Info2} = create_trace_panel(Splitter),
					
					MinLeftPanelSize = 300,
					wxSplitterWindow:splitVertically(Splitter, TraceSettingsPanel, TracePanel, [{sashPosition, MinLeftPanelSize}]),
					
					%% Only RIGHT panel is groving when resizing window
					wxSplitterWindow:setSashGravity(Splitter, 0.1),
					
					wxSplitterWindow:setMinimumPaneSize(Splitter, MinLeftPanelSize),
					
					%% Add to sizers
					wxSizer:add(Sizer, Splitter, [{flag, ?wxEXPAND},
												  {proportion, 1}]),
					
					wxSizer:add(MainSizer, Sizer, [{proportion, 1},
												   {flag, ?wxEXPAND}]),
					
					%%wxPanel:connect(Panel, command_splitter_sash_pos_changed),
					
					wxPanel:setSizer(Panel, MainSizer),
					
					%%error_logger:info_report(["Notebook TAB has been created", {parent, Parent}, {config, Config}, {panel, Panel}, {self_pid, self()}]),
					
					wxAuiNotebook:addPage(Parent, Panel, ETracerConfigName, [{select, true}]),
					
					%% Creat a record for TAB if it not exist, otherwise update only
					
					Object_list = lists:append([{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.parent_panel_id), Parent}], lists:append(Info, Info2)),
					ETracerConfigRec = case etracer:get_etracer_config_record(ETracerConfigName) of
										   {ok, ETracerConfigRecT} ->
											   ETracerConfigRecT#rETracerConfig{
																				erlang_node = ErlangNode,
																				erlang_node_cookie = ErlangNodeCookie,
																				object_list = Object_list
																			   };
										   _->
											   #rETracerConfig{name = ETracerConfigName,
															   erlang_node = ErlangNode,
															   erlang_node_cookie = ErlangNodeCookie,
															   object_list = Object_list
															  }
									   end,
					etracer:set_etracer_config_record(ETracerConfigRec),
					
					%%{value, {_, UndetGauge}} = lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.gauge_id), 1, ETracerConfigRec#rETracerConfig.object_list),
					
					etracer:print_event("New trace panel has been added - "++ETracerConfigName),
					
					{reply, {ok, Panel}, State#state{config = Config}}
			end;
		{error, _Reason} ->
			{reply, {error, "Error occured. See the printout in Erlang shell."} ,State}
	end;

handle_call({appendTraceLog, Destionation, ETracerConfigName, Text}, _From, State) ->
	case appendTraceLog_int(Destionation, ETracerConfigName, Text) of
		ok ->
			{reply, ok, State};
		{error, Reason} ->
			{reply, {error, Reason}, State}
	end;

handle_call({stop}, _From, State) ->
	{stop, normal, ok, State};

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
handle_info({pulse, UndetGauge}, State) ->
	case etracer:get_etracer_config_record(UndetGauge) of
		{ok, TabRec} ->
			case TabRec#rETracerConfig.trace_status of
				on ->
					wxGauge:pulse(UndetGauge),
					
					%%{_,_,GaugeObjMod,_} = UndetGauge,
					%%Value = GaugeObjMod:getValue(UndetGauge),
					%%error_logger:info_report(["pulse...", {gaugeValue, Value}]),
					
					TRef = erlang:send_after(300, self(), {pulse, UndetGauge}),
					etracer:set_etracer_config_record(TabRec#rETracerConfig{gauge_tref = TRef}),
					{noreply, State};
				_->	
					%% Reset Gauge
					{_,_,GaugeObjMod,_} = UndetGauge,
					GaugeObjMod:setValue(UndetGauge, 0),
					etracer:set_etracer_config_record(TabRec#rETracerConfig{gauge_tref = undefined}),
					{noreply, State}
			end;
		_->	{noreply, State}
	end;

handle_info(_Info, State) ->
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_event/2
%% Description: %% Async Events are handled in handle_event as in handle_info
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_event(_WXEvent = #wx{id = Id, 
						   obj = Obj,
						   event = #wxCommand{type = command_text_updated}}, State) ->
	
	%%error_logger:info_report(["Event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
	
	%% Event received from wxTextCtrl object. Read the text from entry.
	case Id of
		?ENTRY_ID_ERLANG_NODE ->
			%% Erlang node
			
			Text = wxTextCtrl:getValue(Obj),
			
			%% Get record of TAB
			%%case get_tab_record(Obj, State) of
			case etracer:get_etracer_config_record(Obj) of
				{ok, TabRec} ->
					%%NewState = add_tab_in_state_record(TabRec#rNOTEBOOK_TAB{erlang_node = erlang:list_to_atom(Text)}, State),
					etracer:set_etracer_config_record(TabRec#rETracerConfig{erlang_node =  erlang:list_to_atom(Text)}),
					{noreply, State};
				_->	{noreply, State}
			end;
		?ENTRY_ID_ERLANG_NODE_COOKIE ->
			%% Erlang node
			
			Text = wxTextCtrl:getValue(Obj),
			
			%% Get record of TAB
			%%case get_tab_record(Obj, State) of
			case etracer:get_etracer_config_record(Obj) of
				{ok, TabRec} ->
					%%NewState = add_tab_in_state_record(TabRec#rNOTEBOOK_TAB{erlang_node_cookie = erlang:list_to_atom(Text)}, State),
					etracer:set_etracer_config_record(TabRec#rETracerConfig{erlang_node_cookie =  erlang:list_to_atom(Text)}),
					{noreply, State};
				_->	{noreply, State}
			end;
		
		?ENTRY_ID_SAVE_LOG_ON_FLY ->
			%% Name of the log file has entered
			{noreply, State};
		
		_-> {noreply, State}
	end;

handle_event(WXEvent = #wx{id = Id, 
							obj = Obj,
							event = #wxCommand{type = command_button_clicked}}, State) ->
	case etracer:get_etracer_config_record(Obj) of
		{ok, TabRec} ->
			ETracerConfigName = TabRec#rETracerConfig.name,
			case Id of
				?BTN_ID_SETUP ->
					%% Open new windows for setting up Trace settings
					
					%%error_logger:info_report(["Event received", {event, WXEvent}, {obj, Obj}, {module, ?MODULE}, {line, ?LINE}]),
					setup_tracemeasure:start(TabRec#rETracerConfig.name),
					{noreply, State};
				
				?BTN_ID_START_STOP ->
					case wxButton:getLabel(Obj) of
						?STOP_TRACE_BTN_LABEL ->
							%% Stop the trace
							
							%% Stop Gauge
							%%catch erlang:cancel_timer(TabRec#rETracerConfig.gauge_tref),
							
							%% Set some GUI objects for the trace
							set_gui_obj_status(ETracerConfigName, stop),
							
							%% Stop tracing
							etracer_worker:stop(ETracerConfigName),
							
							%% Set status of Trace
							etracer:set_etracer_config_record(TabRec#rETracerConfig{trace_status = off}),
							
							{noreply, State};
						
						?START_TRACE_BTN_LABEL ->
							%% Start the trace
							LogFileName = case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_checkbox_id), 1, TabRec#rETracerConfig.object_list) of
											  {value, {_, SaveLogOnFlyCheckBoxObj}} ->
												  {_,_,SaveLogOnFlyCheckBoxMod,_} = SaveLogOnFlyCheckBoxObj,
												  
												  case SaveLogOnFlyCheckBoxMod:getValue(SaveLogOnFlyCheckBoxObj) of
													  true ->
														  case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_entry_id), 1, TabRec#rETracerConfig.object_list) of
															  {value, {_, SaveLogOnFlyEntryObj}} ->
																  {_,_,SaveLogOnFlyEntryMod,_} = SaveLogOnFlyEntryObj,
																  case SaveLogOnFlyEntryMod:getValue(SaveLogOnFlyEntryObj) of
																	  [] ->
																		  %% No filename is set - error
																		  wxMessageDialog:showModal(wxMessageDialog:new(State#state.parent, "Please set the logfile of ",
																														[{style,
																														  ?wxOK bor ?wxICON_ERROR bor ?wxSTAY_ON_TOP},
																														 {caption, ETracerConfigName++" - Please set the logfile"}])),
																		  %%{noreply, State};
																		  error;
																	  
																	  LogFileNameT ->
																		  LogFileNameT
																  end;
															  _-> undefined
														  end;
													  
													  false ->
														  undefined
												  end;
											  _-> undefined
										  end,
							
							case LogFileName of
								error ->
									{noreply, State};
								_->
									
									%% Start tracing...
									
									%% Set some GUI objects for the trace
									set_gui_obj_status(ETracerConfigName, start),
									
									%% Start Gauge
									case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.gauge_id), 1, TabRec#rETracerConfig.object_list) of
										{value, {_, UndetGauge}} ->
											wxGauge:setValue(UndetGauge, 0),
											wxGauge:pulse(UndetGauge),
											erlang:send_after(300, self(), {pulse, UndetGauge});
										_-> do_nothing
									end,
									
									%% Print same detailed info before start tracing
									HeaderFooterLine = string:copies("*", 60),
									
									NewLineChar = etracer:get_new_line_char(),
									
									LogDestination = case LogFileName of
													   undefined ->
														   %% Logging in the GUI
														   editor;
													   _->
														   case fileHandling:openFile(LogFileName, write) of
															   {ok, IoDevice} ->
																   %% Ok, file can be open for write
																   
																   %% Print an info message to the GUI about log messages are going to be put in a file
																   appendTraceLog_int(editor, ETracerConfigName, "Log messages saved in the "++LogFileName++NewLineChar),
																   
																   {ok, IoDevice};
															   {error, ReasonLogFile} ->
																   error_logger:error_report(["Error occured when opeing logfile. Thus the tlace log will be put in the GUI Editor.", {logFile, LogFileName}, {reason, ReasonLogFile}, {module, ?MODULE}, {line, ?LINE}]),
																   editor
														   end
												   end,
									
									appendTraceLog_int(LogDestination, ETracerConfigName, HeaderFooterLine++NewLineChar),
									appendTraceLog_int(LogDestination, ETracerConfigName, "Detailed information"++NewLineChar),
									appendTraceLog_int(LogDestination, ETracerConfigName, HeaderFooterLine++NewLineChar),
									
									appendTraceLog_int(LogDestination, ETracerConfigName, "ETracer version: "++?TOOL_VERSION++NewLineChar),
									appendTraceLog_int(LogDestination, ETracerConfigName, "Erlang node: "++erlang:atom_to_list(TabRec#rETracerConfig.erlang_node)++NewLineChar),
									
									ErlangNodeCookieStr = case etracer:erlang_term_to_string(TabRec#rETracerConfig.erlang_node_cookie) of
															  {ok, ErlangNodeCookieStr_T} ->
																  ErlangNodeCookieStr_T;
															  _-> "error when convert cookie to string"
														  end,
									appendTraceLog_int(LogDestination, ETracerConfigName, "Erlang node cookie: "++ErlangNodeCookieStr++NewLineChar),
									
									MatchSpecStr = case etracer:erlang_term_to_string(etracer_worker:create_trace_match_specification(ETracerConfigName)) of
													   {ok, MatchSpecStr_T} ->
														   MatchSpecStr_T;
													   _-> "error when convert match spec to string"
												   end,
									appendTraceLog_int(LogDestination, ETracerConfigName, "Match specification: "++MatchSpecStr++NewLineChar),
									
									TraceFlags_Str = case etracer:erlang_term_to_string(etracer_worker:get_trace_flag_for_dbg(TabRec#rETracerConfig.trace_flags)) of
														 {ok, TraceFlags_Str_T} ->
															 TraceFlags_Str_T;
														 _-> "error when convert trace flags to string"
													 end,
									appendTraceLog_int(LogDestination, ETracerConfigName, "Trace Flags: "++TraceFlags_Str++NewLineChar),
									
									TracePatternStr = case etracer:erlang_term_to_string(TabRec#rETracerConfig.trace_pattern) of
														  {ok, TracePattern_T} ->
															  TracePattern_T;
														  _-> "error when convert trace pattern to string"
													  end,
									appendTraceLog_int(LogDestination, ETracerConfigName, "Trace patterns: "++NewLineChar++TracePatternStr++NewLineChar),
									appendTraceLog_int(LogDestination, ETracerConfigName, NewLineChar),
									appendTraceLog_int(LogDestination, ETracerConfigName, HeaderFooterLine++NewLineChar),
									appendTraceLog_int(LogDestination, ETracerConfigName, NewLineChar),
									
									etracer_worker:start(ETracerConfigName, [{erlangNode, TabRec#rETracerConfig.erlang_node},
																			 {erlangNodeCookie, TabRec#rETracerConfig.erlang_node_cookie},
																			 {eTracerConfigName, ETracerConfigName},
																			 {logDestination, LogDestination}]),
									
									%% Set status of Trace
									etracer:set_etracer_config_record(TabRec#rETracerConfig{trace_status = on}),
									
									{noreply, State}
							end
					end;
				
				?BTN_ID_SAVE ->
					%% Open a fiel dialog window for setting upthe file to be save the trace file.
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.parent_panel_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, ParentPanelObj}} ->
							FileDlgObj = wxFileDialog:new(ParentPanelObj, []),
							case wxFileDialog:showModal(FileDlgObj) of
								?wxID_OK ->
									%% File selected
									PathWithFileName = wxFileDialog:getPath(FileDlgObj),
									File = wxFileDialog:getFilename(FileDlgObj),
									error_logger:info_report(["FileDlg", {dir_and_file, PathWithFileName}, {file, File}]),
									
									{value, {_, TraceLogWindowObj}} = lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.trace_log_window_id), 1, TabRec#rETracerConfig.object_list),
									Text = wxStyledTextCtrl:getText(TraceLogWindowObj),
									
									case fileHandling:openFile(PathWithFileName, write) of
										{ok, IoDevice} ->
											fileHandling:writeLine(IoDevice, Text),
											fileHandling:closeFile(IoDevice);
										{error, Reason} ->
											error_logger:error_report(["Error occured at saving trace log into a file", {reason, Reason}])
									end,
									{noreply, State};
								
								_->	%% Cancel
									{noreply, State}
							end;
						_->	{noreply, State}
					end;
				
				?BTN_ID_CLEAR ->
					%% Clear trace log
					%%error_logger:info_report(["Clear Btn has pressed"]),
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.trace_log_window_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, TraceWindowObj}} ->
							{_,_,TraceWindowObjMod,_} = TraceWindowObj,
							%%error_logger:info_report(["Clear Btn has pressed", {obj, TraceWindowObj}]),
							
							TraceWindowObjMod:setReadOnly(TraceWindowObj, false),
							TraceWindowObjMod:clearAll(TraceWindowObj),
							TraceWindowObjMod:setReadOnly(TraceWindowObj, true);
						
						_-> do_nothing
					end,
					{noreply, State};
				
				_->
					error_logger:info_report(["Unexpected event received", {event, WXEvent}, {module, ?MODULE}, {line, ?LINE}]),
					{noreply, State}
			end;
		_->	{noreply, State}
	end;

handle_event(_WXEvent = #wx{id = _Id,
						   obj = Obj,
						   event = #wxStyledText{type = stc_change}}, State) ->
	%% Trace window updated
	
	LW = string:len(erlang:integer_to_list(wxStyledTextCtrl:getLineCount(Obj))),
	
	wxStyledTextCtrl:setMarginWidth(Obj, 0, LW+25),	
	wxStyledTextCtrl:setMarginWidth(Obj, 1, 0),
	
	%%error_logger:info_report(["Trace window updated", {event, WXEvent}, {lw, LW}, {module, ?MODULE}, {line, ?LINE}]),
	
	{noreply, State};

handle_event(_WXEvent = #wx{obj = Notebook,
						   event = #wxAuiNotebook{type = command_auinotebook_page_changed,
												  selection = Sel}}, State) ->
	%%error_logger:info_report(["You have changed a page.", {event, WXEvent}, {module, ?MODULE}, {line, ?LINE}]),
	
	%% Print all children of this TAB just for test
	%%error_logger:info_report(["List of children", {children, getChildren_int(Notebook)}, {module, ?MODULE}, {line, ?LINE}]),
	
	{noreply, State#state{selected_tab_number = Sel, selected_tab_name = wxAuiNotebook:getPageText(Notebook, Sel)}};

handle_event(_WXEvent = #wx{event = #wxAuiNotebook{type = command_auinotebook_page_close}}, State) ->
	ETracerConfigName = State#state.selected_tab_name,
	%%error_logger:info_report(["You have closed a page.", {event, WXEvent}, {tracerName, ETracerConfigName}, {module, ?MODULE}, {line, ?LINE}]),
	
	PressedButton = wxMessageDialog:showModal(wxMessageDialog:new(State#state.parent, "Do you want to remove settings of "++ETracerConfigName++" from database too?",
																  [{style,
																	?wxYES_NO bor ?wxICON_INFORMATION bor ?wxSTAY_ON_TOP},
																   {caption, ETracerConfigName++" - Tracer TAB closed"}])),
	
	etracer:print_event("Trace panel has been closed - "++ETracerConfigName),
	
	case PressedButton of
		?wxID_NO ->
			{noreply, State};
		?wxID_YES ->
			%% Remove record in MNESIA
			etracer:delete_etracer_config_record(ETracerConfigName),
			etracer:print_event("Trace panel has been closed and all data removed from database- "++ETracerConfigName),
			{noreply, State}
	end;

handle_event(_WXEvent = #wx{id = Id,
							obj  = ChBoxObj,
							event = #wxCommand{type = command_checkbox_clicked,
											   commandInt = _Int}},
			 State = #state{config = _Config}) ->
	case Id of
		?FILTERBOX_CHECKBOX_ID_SAVE_LOG_ON_FLY ->
			ETracerConfigName = State#state.selected_tab_name,
			
			%%Value = wxCheckBox:getValue(ChBoxObj),
			%%error_logger:info_report(["CheckBx Value", {value, Value}]),
			
			case etracer:get_etracer_config_record(ETracerConfigName) of
				{ok, TabRec} when is_record(TabRec, rETracerConfig)->
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_entry_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, Obj}} ->
							{_,_,ObjMod,_} = Obj,
							
							case wxCheckBox:getValue(ChBoxObj) of
								true ->
									ObjMod:enable(Obj);
								_->	ObjMod:disable(Obj)
							end;
						
						_->	%% Error, entry object does not found
							do_nothing
					end;
				
				_->	%% Error, record of selected ETracer does not found
					do_nothing
			end,
						
			{noreply, State};
		
		_->	{noreply, State}
	end;

handle_event(WXEvent,State) ->
	error_logger:info_report(["Unexpected event received", {event, WXEvent}, {module, ?MODULE}, {line, ?LINE}]),
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	%%error_logger:info_report(["terminate received", {reason, Reason}, {state, State}, {module, ?MODULE}, {line, ?LINE}]),
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

%% --------------------------------------------------------------------
%% Create panel object
%% --------------------------------------------------------------------
create_trace_panel(Parent) ->
	Panel = wxPanel:new(Parent),
	Sz = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, "Trace log"}]),
	wxPanel:setSizer(Panel, Sz),
	
	FixedFont = wxFont:new(10, ?wxFONTFAMILY_TELETYPE, ?wxNORMAL, ?wxNORMAL,[]),
	Ed = wxStyledTextCtrl:new(Panel),
	
	wxStyledTextCtrl:styleClearAll(Ed),
	wxStyledTextCtrl:styleSetFont(Ed, ?wxSTC_STYLE_DEFAULT, FixedFont),
	wxStyledTextCtrl:setLexer(Ed, ?wxSTC_LEX_ERLANG),
	wxStyledTextCtrl:setMarginType(Ed, 0, ?wxSTC_MARGIN_NUMBER),
	LW = wxStyledTextCtrl:textWidth(Ed, ?wxSTC_STYLE_LINENUMBER, "9"),
	wxStyledTextCtrl:setMarginWidth(Ed, 0, LW+5),
	wxStyledTextCtrl:setMarginWidth(Ed, 1, 0),
	
	wxStyledTextCtrl:setSelectionMode(Ed, ?wxSTC_SEL_LINES),
	%%wxStyledTextCtrl:hideSelection(Ed, true),
	
	Styles =  [{?wxSTC_ERLANG_DEFAULT,  {0,0,0}},
			   {?wxSTC_ERLANG_COMMENT,  {160,53,35}},
			   {?wxSTC_ERLANG_VARIABLE, {150,100,40}},
			   {?wxSTC_ERLANG_NUMBER,   {5,5,100}},
			   {?wxSTC_ERLANG_KEYWORD,  {130,40,172}},
			   {?wxSTC_ERLANG_STRING,   {170,45,132}},
			   {?wxSTC_ERLANG_OPERATOR, {30,0,0}},
			   {?wxSTC_ERLANG_ATOM,     {0,0,0}},
			   {?wxSTC_ERLANG_FUNCTION_NAME, {64,102,244}},
			   {?wxSTC_ERLANG_CHARACTER,{236,155,172}},
			   {?wxSTC_ERLANG_MACRO,    {40,144,170}},
			   {?wxSTC_ERLANG_RECORD,   {40,100,20}},
			   {?wxSTC_ERLANG_SEPARATOR,{0,0,0}},
			   {?wxSTC_ERLANG_NODE_NAME,{0,0,0}}],
	SetStyle = fun({Style, Color}) ->
					   wxStyledTextCtrl:styleSetFont(Ed, Style, FixedFont),
					   wxStyledTextCtrl:styleSetForeground(Ed, Style, Color)
			   end,
	[SetStyle(Style) || Style <- Styles],
	wxStyledTextCtrl:setKeyWords(Ed, 0, keyWords()),
	
	%% Scrolling
	Policy = ?wxSTC_CARET_SLOP bor ?wxSTC_CARET_JUMPS bor ?wxSTC_CARET_EVEN, 
	wxStyledTextCtrl:setYCaretPolicy(Ed, Policy, 3),
	wxStyledTextCtrl:setVisiblePolicy(Ed, Policy, 3),
	
	%%wxStyledTextCtrl:connect(Ed, stc_doubleclick),
	wxStyledTextCtrl:connect(Ed, stc_change),
	wxStyledTextCtrl:setReadOnly(Ed, true),
	
	wxSizer:add(Sz, Ed, [{proportion, 1}, {flag, ?wxEXPAND}]),
	
	{Panel, [{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.trace_log_window_id), Ed}]}.

%% --------------------------------------------------------------------
%% Create trace settings panel
%% --------------------------------------------------------------------
create_trace_settings_panel(ErlangNode, ErlangNodeCookie) ->
	fun(Parent) ->
			Panel = wxPanel:new(Parent, []),
			
			MainSizer = wxBoxSizer:new(?wxVERTICAL),
			
			wxSizer:addSpacer(MainSizer, 20),
			
			ErlangNodeSizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, "Enter Erlang node"}]),
			wxSizer:add(MainSizer, ErlangNodeSizer,  [{flag, ?wxEXPAND}]),
			ErlangNodeTextCtrl = wxTextCtrl:new(Panel, ?ENTRY_ID_ERLANG_NODE, [{value, erlang:atom_to_list(ErlangNode)}, 
																			   {style, ?wxDEFAULT}]),
			wxTextCtrl:connect(ErlangNodeTextCtrl, command_text_updated),
			wxSizer:add(ErlangNodeSizer, ErlangNodeTextCtrl, [{flag, ?wxEXPAND}]),
			wxSizer:addSpacer(MainSizer, 10),
			
			ErlangNodeCookieSizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, "Enter Erlang node cookie"}]),
			wxSizer:add(MainSizer, ErlangNodeCookieSizer,  [{flag, ?wxEXPAND}]),
			ErlangNodeCookieTextCtrl = wxTextCtrl:new(Panel, ?ENTRY_ID_ERLANG_NODE_COOKIE, [{value, erlang:atom_to_list(ErlangNodeCookie)}, 
																							{style, ?wxDEFAULT}]),
			wxTextCtrl:connect(ErlangNodeCookieTextCtrl, command_text_updated),
			wxSizer:add(ErlangNodeCookieSizer, ErlangNodeCookieTextCtrl, [{flag, ?wxEXPAND}]),
			wxSizer:addSpacer(MainSizer, 10),
			
			TraceMeasureButton = wxButton:new(Panel, ?BTN_ID_SETUP, [{label, "Setup Tracemeasure"}]),
			wxSizer:add(MainSizer, TraceMeasureButton, [{border, 5}, {flag, ?wxALL}]),
			wxButton:connect(TraceMeasureButton, command_button_clicked),
			
			StartStopSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel, [{label, ""}]),
			wxSizer:add(MainSizer, StartStopSizer,  [{flag, ?wxEXPAND}]),
			
			StartStopTraceButton = wxButton:new(Panel, ?BTN_ID_START_STOP, [{label, ?START_TRACE_BTN_LABEL}]),
			wxSizer:add(StartStopSizer, StartStopTraceButton, [{border, 5}, {flag, ?wxALL}]),
			wxButton:connect(StartStopTraceButton, command_button_clicked),
			
			SaveTraceButton = wxButton:new(Panel, ?BTN_ID_SAVE, [{label, "Save Trace"}]),
			wxSizer:add(StartStopSizer, SaveTraceButton, [{border, 5}, {flag, ?wxALL}]),
			wxButton:connect(SaveTraceButton, command_button_clicked),
			
			ClearTraceButton = wxButton:new(Panel, ?BTN_ID_CLEAR, [{label, "Clear Trace"}]),
			wxSizer:add(StartStopSizer, ClearTraceButton, [{border, 5}, {flag, ?wxALL}]),
			wxButton:connect(ClearTraceButton, command_button_clicked),
			
			%%
			SaveLogInFileOnTheFlySizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, ""}]),
			wxSizer:add(MainSizer, SaveLogInFileOnTheFlySizer,  [{flag, ?wxEXPAND}]),
			LogFileNameCheckBox = wxCheckBox:new(Panel, ?FILTERBOX_CHECKBOX_ID_SAVE_LOG_ON_FLY, "Save log in a file on the fly", []),
			wxCheckBox:connect(LogFileNameCheckBox, command_checkbox_clicked),
			wxSizer:add(SaveLogInFileOnTheFlySizer, LogFileNameCheckBox, [{border, 5}, {flag, ?wxEXPAND}]),
			
			wxSizer:addSpacer(SaveLogInFileOnTheFlySizer, 10),
			
			LogFileNameTextCtrl = wxTextCtrl:new(Panel, ?ENTRY_ID_SAVE_LOG_ON_FLY, [{value, ""}, 
																					{style, ?wxDEFAULT}]),
			%% Disable object by default
			wxTextCtrl:disable(LogFileNameTextCtrl),
			wxTextCtrl:connect(LogFileNameTextCtrl, command_text_updated),
			wxSizer:add(SaveLogInFileOnTheFlySizer, LogFileNameTextCtrl, [{border, 5}, {flag, ?wxEXPAND}]),
			
			%%
			
			wxSizer:addSpacer(MainSizer, 10),
			
			Range = 100,
			UndetGauge = wxGauge:new(Panel, ?UNDETERMINISTIC_GAUGE_ID, Range, [{size, {200, -1}},
																			   {style, ?wxGA_HORIZONTAL}]),
			wxSizer:add(MainSizer, UndetGauge,  [{flag, ?wxEXPAND}]),
			
			wxPanel:setSizer(Panel, MainSizer),
			wxSizer:layout(MainSizer),
			
			Info = [{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.setup_tracemeasure_btn_id), TraceMeasureButton}, 
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.start_stop_trace_btn_id), StartStopTraceButton},
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.save_trace_btn_id), SaveTraceButton},
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.clear_trace_btn_id), ClearTraceButton},
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.erlang_node_entry_id), ErlangNodeTextCtrl},
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.erlang_node_cookie_entry_id), ErlangNodeCookieTextCtrl},
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_checkbox_id), LogFileNameCheckBox},
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_entry_id), LogFileNameTextCtrl},
					{?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.gauge_id), UndetGauge}],
			{Panel, Info}
	end.

%% --------------------------------------------------------------------
%% Setup keywords for trace window.
%% --------------------------------------------------------------------
keyWords() ->
	L = ["after","begin","case","try","cond","catch","andalso","orelse",
		 "end","fun","if","let","of","query","receive","when","bnot","not",
		 "div","rem","band","and","bor","bxor","bsl","bsr","or","xor"],
	lists:flatten([K ++ " " || K <- L] ++ [0]).

%% --------------------------------------------------------------------
%% Give the list of name of TABs already created on Notebook
%% Input:
%%		Notebook	:	#wx_ref{}
%% Output:
%%		{ok, List} | {error, Reason}
%% --------------------------------------------------------------------
getNotebookTabNames_int(Notebook) when is_record(Notebook, wx_ref) ->
	case catch wxAuiNotebook:getPageCount(Notebook) of
		Cnt when is_integer(Cnt) ->
			
			L = [begin
					 wxAuiNotebook:getPageText(Notebook, I)
				 end || I <- lists:seq(0, Cnt-1)],
			{ok, L};
		Reason ->
			%%error_logger:error_report(["Error occured when calling getNotebookTabNames/1", {notebook, Notebook}, {reason, Reason}]),
			{error, Reason}
	end.

%% getChildren_int(Obj) ->
%% 	case catch wxWindow:getChildren(Obj) of
%% 		L when is_list(L) ->
%% 			%%error_logger:info_report(["Get Children", {obj, Obj}, {childrenList, L}]),
%% 			L;
%% 		Error ->
%% 			%%error_logger:info_report(["Get Children", {obj, Obj}, {error, Error}]),
%% 			ok
%% 	end.

%% --------------------------------------------------------------------
%% Disable/Enable GUI objects during/after tracing
%% Input:
%%		ETracerConfigName	:	string
%%		TraceStatus			:	atom(), status of Traceing. It can be: start | stop
%% Output:
%%		ok
%% --------------------------------------------------------------------
set_gui_obj_status(ETracerConfigName, TraceStatus) ->
	case etracer:get_etracer_config_record(ETracerConfigName) of
		{ok, TabRec} when is_record(TabRec, rETracerConfig)->
			
			ObjList1 = [#rTRACER_TAB_OBJECT_NAMES.erlang_node_entry_id,
						#rTRACER_TAB_OBJECT_NAMES.erlang_node_cookie_entry_id,
						#rTRACER_TAB_OBJECT_NAMES.setup_tracemeasure_btn_id,
						#rTRACER_TAB_OBJECT_NAMES.save_trace_btn_id,
						#rTRACER_TAB_OBJECT_NAMES.clear_trace_btn_id,
						#rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_checkbox_id,
						#rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_entry_id
					   ],
			
			case TraceStatus of
				start ->
					%% Disable the following GUI objects
					[begin
						 case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, ObjName), 1, TabRec#rETracerConfig.object_list) of
							 {value, {_, Obj}} ->
								 {_,_,ObjMod,_} = Obj,
								 ObjMod:disable(Obj);
							 _-> do_nothing
						 end
					 end || ObjName <- ObjList1],
					
					%% Set label of Start/Stop button to "Stop Trace"
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.start_stop_trace_btn_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, Obj}} ->
							{_,_,ObjMod,_} = Obj,
							ObjMod:setLabel(Obj, "Stop Trace");
						_-> do_nothing
					end,
					
					%% Reset Gauge
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.gauge_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, UndetGauge}} ->
							{_,_,GaugeObjMod,_} = UndetGauge,
							GaugeObjMod:setValue(UndetGauge, 0);
						_-> do_nothing
					end,
					
					ok;
				stop ->
					%% Enable these
					[begin
						 case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, ObjName), 1, TabRec#rETracerConfig.object_list) of
							 {value, {_, Obj}} ->
								 {_,_,ObjMod,_} = Obj,
								 
								 %% Do same special for save_log_on_fly_entry_id
								 case ObjName of
									 #rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_entry_id ->
										 %% Enable this object if save_log_on_fly_checkbox_id is checked in, otherwise disable.
										 case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.save_log_on_fly_checkbox_id), 1, TabRec#rETracerConfig.object_list) of
											 {value, {_, CheckBoxObj}} ->
												 {_,_,CheckBoxObjMod,_} = CheckBoxObj,
												 case CheckBoxObjMod:getValue(CheckBoxObj) of
													 true ->
														 ObjMod:enable(Obj);
													 _-> ObjMod:disable(Obj)
												 end;
											 _-> ObjMod:disable(Obj)
										 end;
									 
									 _-> ObjMod:enable(Obj)
								 end;
							 
							 _-> do_nothing
						 end
					 end || ObjName <- ObjList1],
					
					%% Set label of Start/Stop button to "Start Trace"
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.start_stop_trace_btn_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, Obj}} ->
							{_,_,ObjMod,_} = Obj,
							ObjMod:setLabel(Obj, "Start Trace");
						_-> do_nothing
					end,
					
					%% Reset Gauge
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.gauge_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, UndetGauge}} ->
							{_,_,GaugeObjMod,_} = UndetGauge,
							GaugeObjMod:setValue(UndetGauge, 0);
						_-> do_nothing
					end,
					
					ok
			end;
		
		_->	ok
	end.

%% --------------------------------------------------------------------
%% Add trace log into the trace window
%% Input:
%%		LogDestination		:	editor | {ok, IoDevice}
%%		ETracerConfigName	:	string
%%		Text				:	string
%% Output:
%%		ok | {error, Reason}
%% --------------------------------------------------------------------
appendTraceLog_int(LogDestination, ETracerConfigName, Text) ->
	case LogDestination of
		editor ->
			%% Get TabRec first
			case etracer:get_etracer_config_record(ETracerConfigName) of
				{ok, TabRec} when is_record(TabRec, rETracerConfig)->
					case lists:keysearch(?GET_RECORD_FIELD_NAME(?TRACER_TAB_OBJECT_NAMES, #rTRACER_TAB_OBJECT_NAMES.trace_log_window_id), 1, TabRec#rETracerConfig.object_list) of
						{value, {_, Obj}} ->
							{_,_,ObjMod,_} = Obj,
							
							%% Turn OFF readonly
							ObjMod:setReadOnly(Obj, false),
							
							%%error_logger:info_report(["appendTraceLog", {obj, Obj}, {text, Text}, {module, ?MODULE}, {line, ?LINE}]),
							case ObjMod:appendText(Obj, Text) of
								ok ->
									%% Turn ON readonly
									ObjMod:setReadOnly(Obj, true),
									ok;
								Error ->
									%% Turn ON readonly
									ObjMod:setReadOnly(Obj, true),
									{error, Error}
							end;
						false ->
							{error, false}
					end;
				
				{error, Reason} ->
					{error, Reason}
			end;
		
		{ok, IoDevice} ->
			fileHandling:writeLine(IoDevice, Text),
			ok
	end.

%% %% --------------------------------------------------------------------
%% %% Add new TAB in State record
%% %% Input:
%% %%		TabRec	:	#rNOTEBOOK_TAB{}
%% %%		State	:	#state{}
%% %% Output:
%% %%		NewState:	#state{}
%% %% --------------------------------------------------------------------
%% add_tab_in_state_record(TabRec, State) ->
%% 	NewState = case lists:keyfind(TabRec#rNOTEBOOK_TAB.name, 2, State#state.tab_list) of
%% 				   TabRec2 when is_record(TabRec2, rNOTEBOOK_TAB) ->
%% 					   State#state{tab_list = lists:keyreplace(TabRec#rNOTEBOOK_TAB.name, 2, State#state.tab_list, TabRec)};
%% 				   _-> State#state{tab_list = lists:append(State#state.tab_list, [TabRec])}
%% 			   end,
%% 	
%% 	error_logger:info_report(["add_tab_in_state_record", {old_state, State}, {new_sate, NewState}]),
%% 	NewState.
%% 
%% %% --------------------------------------------------------------------
%% %% Get TAB ETracerConfigRec in State record
%% %% Input:
%% %%		ETracerConfigName	:	string
%% %%		State	:	#state{}
%% %% Output:
%% %%		TabRec	:	{ok, #rNOTEBOOK_TAB{}} | {error, Reason}
%% %% --------------------------------------------------------------------
%% get_tab_record(ETracerConfigName, State) when is_list(ETracerConfigName)->
%% 	case lists:keysearch(ETracerConfigName, 2, State#state.tab_list) of
%% 		{value, TabRec} ->
%% 			{ok, TabRec};
%% 		Reason ->
%% 			{error, Reason}
%% 	end;
%% 
%% %% --------------------------------------------------------------------
%% %% Get TAB ETracerConfigRec in State record by Obj Id
%% %% Input:
%% %%		Obj		:	wxWindow()
%% %%		State	:	#state{}
%% %% Output:
%% %%		TabRec	:	{ok, #rNOTEBOOK_TAB{}} | {error, Reason}
%% %% --------------------------------------------------------------------
%% get_tab_record(Obj, State) when is_record(Obj, wx_ref)->
%% 	do_get_tab_rec_in_state_record(Obj, State#state.tab_list).
%% 
%% do_get_tab_rec_in_state_record(Obj, []) ->
%% 	{error, "TAB record does not found"};
%% do_get_tab_rec_in_state_record(Obj, [TabRec | Tail]) ->
%% 	%% Check that Obj is in TabRec
%% 	ObjList = TabRec#rNOTEBOOK_TAB.object_list,
%% 	case lists:keysearch(Obj, 2, ObjList) of
%% 		{value, _} ->
%% 			{ok, TabRec};
%% 		_->	do_get_tab_rec_in_state_record(Obj, Tail)
%% 	end.

