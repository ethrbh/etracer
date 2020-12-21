%% Author: ethrbh
%% Created: Jun 22, 2012
%% Description: TODO: Add description to tracer
-module(setup_tracemeasure).

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
-include("../include/wxFilterBox.hrl").

%% --------------------------------------------------------------------
%% Trace Measure related exports
%% --------------------------------------------------------------------
-export([
		 notify/2
		 ]).

%% --------------------------------------------------------------------
%% WX related exports
%% --------------------------------------------------------------------
-export([start/1, start_link/1, stop/1,
		 format/3, 
		 init/1,  
		 handle_cast/2, handle_call/3, handle_info/2, handle_event/2,
		 terminate/2,  
		 code_change/3]).

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------
-record(state, {win,
				eTracerConfigName,
				obj_list = []}).

%% --------------------------------------------------------------------
%% Defines
%% --------------------------------------------------------------------
-define(SERVER(ETracerConfigName), begin erlang:list_to_atom(erlang:atom_to_list(?MODULE)++"_"++ETracerConfigName) end).
-define(MODULE_SELECTION_SERVER(ETracerConfigName), begin erlang:list_to_atom(erlang:atom_to_list(module_selection)++"_"++ETracerConfigName) end).
-define(FUNCTION_SELECTION_SERVER(ETracerConfigName), begin erlang:list_to_atom(erlang:atom_to_list(function_selection)++"_"++ETracerConfigName) end).
-define(TRACEPATTERN_SELECTION_SERVER(ETracerConfigName), begin erlang:list_to_atom(erlang:atom_to_list(tracepattern_selection)++"_"++ETracerConfigName) end).

-define(WX_CHECKBOX_ID_TRACE_FLAG_MESSAGE, 1).
-define(WX_CHECKBOX_ID_TRACE_FLAG_SEND, 2).
-define(WX_CHECKBOX_ID_TRACE_FLAG_RECEIVE, 3).
-define(WX_CHECKBOX_ID_TRACE_FLAG_CALL, 4).
-define(WX_CHECKBOX_ID_TRACE_FLAG_PROC, 5).

-define(WX_CHECKBOX_ID_MATCHSPEC_FLAG_MESSAGE, 6).
-define(WX_CHECKBOX_ID_MATCHSPEC_FLAG_PROCESSDUMP, 7).
-define(WX_CHECKBOX_ID_MATCHSPEC_FLAG_RETURNTRACE, 8).

-define(WX_BUTTON_ID_SAVETOTRACEPATTERN, 9).
-define(WX_BUTTON_ID_DELETEINTRACEPATTERN, 10).

-define(WX_TEXTCTRL_ID_MATCH_SPEC, 1).

-define(MODULE_FUNCTION_SEPARATOR, ":").
-define(FUNCTION_ARITY_SEPARATOR, "/").
-define(SPECIAL_TAG_FOR_ALL_FUNCTIONS_ARE_SELECTED, "ALL_FUNCTIONS").

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% @spec notify(SendTo, Info) -> ok | {error, Reason}
%% SendTo	=	pid() of the process to be send the message. Basically this is the pid() of "Setup TraceMeasure" process started for the "ETracerConfigName"
%% Info		=	term()
%%
%% @doc
%% Someone can notify Trace Measure process about something happened.
%% Basically I planed to use it when FilterBox did someting for example
%% an item selected, it can notify Trace Measure about it, thus it can
%% control the Module/Function selection procedure.
%% @end
%% --------------------------------------------------------------------
notify(SendTo, Info) when is_pid(SendTo)->
	case erlang:is_process_alive(SendTo) of
		true ->
			%% Trace Measure server is alive. Forward the Info to him.
			SendTo ! Info,
			ok;
		Reason ->
			{error, Reason}
	end.
	
%% --------------------------------------------------------------------
%% @spec start(ETracerConfigName) -> {ok, Pid} | {error, Reason}
%% ETracerConfigName	=	string, name of the Tracer TAB where setup tracemeasure wsa initiate.
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start(ETracerConfigName) when is_list(ETracerConfigName)->
	case catch wx_object:start({local, ?SERVER(ETracerConfigName)}, ?MODULE, ETracerConfigName, []) of
		Ref when is_record(Ref, wx_ref) ->
			Ref;
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% @spec start(ETracerConfigName) -> Ref:wxWindow() | {error, Reason}
%% ETracerConfigName	=	string, name of the Tracer TAB where setup tracemeasure wsa initiate.
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start_link(ETracerConfigName) when is_list(ETracerConfigName)->
	case catch wx_object:start_link({local, ?SERVER(ETracerConfigName)}, ?MODULE, ETracerConfigName, []) of
		Ref when is_record(Ref, wx_ref) ->
			Ref;
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% @spec stop(ETracerConfigName) -> ok | {error, Reason}
%% ETracerConfigName	=	string, name of the Tracer TAB where setup tracemeasure wsa initiate.
%% @doc
%% Stop WX process
%% @end
%% --------------------------------------------------------------------
stop(ETracerConfigName) ->
	Server = ?SERVER(ETracerConfigName),
	case whereis(Server) of
		P when is_pid(P) ->
			case wx_object:call(Server, {stop}, ?WX_OBJECT_CALL_TO) of
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
%% @spec init(ETracerConfigRec) -> {Frame, #state{}}
%% ETracerConfigRec	=	#rETracerConfig{}
%% @doc
%% Init WX server
%% Optins can be: 
%%		{parent, <PARENT>}
%% @end
%% --------------------------------------------------------------------
init(ETracerConfigName) when is_list(ETracerConfigName) ->
	wx:new([]),
	%%process_flag(trap_exit, true),
	
	{ok, ETracerConfigRec} = etracer:get_etracer_config_record(ETracerConfigName),
	
	%% --------------------------------------------------------------------
	%% Do not touch this part!!
	%% --------------------------------------------------------------------
 	%% Create a new frame 
 	FrameWidth = 500,
 	FrameHigh = 650,
 	Frame = wxFrame:new(wx:null(), ?wxID_ANY, "Setup tracemeasure for "++ETracerConfigName, [{size,{FrameWidth,FrameHigh}}]),

	Panel = wxPanel:new(Frame, []),
	%%DefaultPanelColor = wxPanel:getBackgroundColour(Panel),
	
 	MainSizer = wxBoxSizer:new(?wxVERTICAL),
	Sizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, ""}]),
 	Splitter = wxSplitterWindow:new(Panel, [{style, ?wxSP_BORDER}]),
	%% --------------------------------------------------------------------
	%% Do not touch this part END
	%% --------------------------------------------------------------------
	
 	TopPanel = create_top_panel(ETracerConfigName, Splitter, ""),
 	{BottomPanel, BottomPanelObjList} = create_bottom_panel(Splitter, ""),
	
	%% --------------------------------------------------------------------
	%% This is a good example. Do not touch
	%% --------------------------------------------------------------------
	%%TopPanel = wxTextCtrl:new(Splitter, ?ENTRY_ID_NEWTRACE, [{value, "TopPanel"}, {style, ?wxDEFAULT}]),
	%%BottomPanel = wxTextCtrl:new(Splitter, ?ENTRY_ID_NEWTRACE, [{value, "BottomPanel"}, {style, ?wxDEFAULT}]),
	%% --------------------------------------------------------------------
	%% This is a good example. Do not touch - END
	%% --------------------------------------------------------------------	

	%% --------------------------------------------------------------------
	%% Do not touch this part!! splitVertically | splitHorizontally
	%% --------------------------------------------------------------------
	wxSplitterWindow:splitHorizontally(Splitter, TopPanel, BottomPanel, [{sashPosition,FrameHigh-200}]),
	wxSplitterWindow:setSashGravity(Splitter, 1.0),
	wxSplitterWindow:setMinimumPaneSize(Splitter, 100),
	wxSizer:add(Sizer, Splitter, [{flag, ?wxEXPAND}, {proportion, 1}]),
	wxSizer:add(MainSizer, Sizer, [{proportion, 1},{flag, ?wxEXPAND}]),
	wxPanel:setSizer(Panel, MainSizer),
	%% --------------------------------------------------------------------
	%% Do not touch this part END
	%% --------------------------------------------------------------------
	
	%% Get Erlang Node name for fetching its available modules
	ErlangNode = ETracerConfigRec#rETracerConfig.erlang_node,
	ErlanNodeCookie = ETracerConfigRec#rETracerConfig.erlang_node_cookie,
	
	%% Setup cookie using on remote node for having access
	erlang:set_cookie(ErlangNode, ErlanNodeCookie),
	
	case etracer:get_modules(ErlangNode) of
		{ok, ModuleList} ->
			ModuleSelectionServer = ?MODULE_SELECTION_SERVER(ETracerConfigName),
			wxFilterBox:filterBoxCtrl_Clear(ModuleSelectionServer),
			wxFilterBox:filterBoxCtrl_AppendItems(ModuleSelectionServer, [erlang:atom_to_list(Mod) || Mod <- ModuleList]);
		_->	do_nothing
	end,
	
	%% -------------------------------------------------------------
	%% Get data from MNESIA and fill all visible objects with these.
	%% -------------------------------------------------------------
	
	%% Setup Trace Pattern
	TracePatternSelectionServer = ?TRACEPATTERN_SELECTION_SERVER(ETracerConfigName),
	wxFilterBox:filterBoxCtrl_Clear(TracePatternSelectionServer),
	wxFilterBox:filterBoxCtrl_AppendItems(TracePatternSelectionServer, 
                                          convert_trace_pattern_to_string(ETracerConfigRec#rETracerConfig.trace_pattern)),
	
	%% Setup Trace Flags
	case lists:keysearch(trace_flag, 1, BottomPanelObjList) of
		{value, {_, TraceFlagObjList}} ->
			[begin
				 case lists:keysearch(TraceFlagName, 1, TraceFlagObjList) of
					 {value, {_, TraceFlagObj}} ->
						 TraceFlagStatus = lists:member(TraceFlagName, ETracerConfigRec#rETracerConfig.trace_flags),
						 wxCheckBox:setValue(TraceFlagObj, TraceFlagStatus);
					 _-> do_nothing
				 end
			 end || TraceFlagName <- [?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.call),
									  ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.message),
									  ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.procs),
									  ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.'receive'),
									  ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.send)
									 ]],
			ok;
		_->	do_nothing
	end,
	
	%% Setup Match Specifications Flags
	case lists:keysearch(trace_matchspecification_flag, 1, BottomPanelObjList) of
		{value, {_, TraceMatchSpecificationFlagObjList}} ->
			[begin
				 case lists:keysearch(TraceMatchSpecificationFlagName, 1, TraceMatchSpecificationFlagObjList) of
					 {value, {_, TraceMatchSpecificationFlagObj}} ->
						 TraceMatchSpecificationFlagStatus = lists:member(TraceMatchSpecificationFlagName, ETracerConfigRec#rETracerConfig.trace_match_spec_flags),
						 wxCheckBox:setValue(TraceMatchSpecificationFlagObj, TraceMatchSpecificationFlagStatus);
						 %%error_logger:info_report(["Setting up Trace Match Spec. flag", {flag, TraceMatchSpecificationFlagName}, {status, TraceMatchSpecificationFlagStatus}, {obj, TraceMatchSpecificationFlagObj}])
					 _-> do_nothing
				 end
			 end || TraceMatchSpecificationFlagName <- [?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.message),
														?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.process_dump),
														?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.return_trace)
													   ]],
			ok;
		_->	do_nothing
	end,
	
	wxFrame:show(Frame),
	
    {Panel, #state{win = Frame, 
				   eTracerConfigName = ETracerConfigRec#rETracerConfig.name, 
				   obj_list = BottomPanelObjList}}.

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
handle_info(_Info = {MsgId, #rFILTERBOX_ACTIONS.command_listbox_selected, ModuleList}, State) ->
	%% FilterBox - ?MODULE_SELECTION_SERVER sent a message about
	%% some Module had been selected in the listbox.
	%%
	%% ModuleList can be:
	%% atom()	-	when one module selected
	%% list()	-	list of atom, names of the selected modules
	%% all		-	all as an atom(). This means that all modules are selected
	%%
	%% Trace Measure will notif y?FUNCTION_SELECTION_SERVER about changes.
		
	case MsgId of
		'MODULE_SELECTION' ->
			
			case ModuleList of
				all ->
					%% All modules are selected. In this case must clear Function Filterbox
					wxFilterBox:filterBoxCtrl_Clear(?FUNCTION_SELECTION_SERVER(State#state.eTracerConfigName)),
					ok;
				[Mod] when is_atom(Mod) ->
					%% Only one module was select, thus must fetch its functions
					%% and pass this list to ?FUNCTION_SELECTION_SERVER
					
					{ok, ETracerConfigRec} = etracer:get_etracer_config_record(State#state.eTracerConfigName),
					
					ErlangNode = ETracerConfigRec#rETracerConfig.erlang_node,
					
					FuncList = get_functions(ErlangNode, Mod),
					%%io:format("FuncList: ~p~n", [FuncList]),
					
					wxFilterBox:filterBoxCtrl_Clear(?FUNCTION_SELECTION_SERVER(State#state.eTracerConfigName)),
					wxFilterBox:filterBoxCtrl_AppendItems(?FUNCTION_SELECTION_SERVER(State#state.eTracerConfigName), FuncList),
					
					ok;
				
				ModList when is_list(ModList) ->
					wxFilterBox:filterBoxCtrl_Clear(?FUNCTION_SELECTION_SERVER(State#state.eTracerConfigName)),
					ok
			end;
		
		'FUNCTION_SELECTION' ->
			ok;
		_->	ok
	end,
	
	{noreply, State};
	
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
						   obj = _Obj,
						   event = #wxCommand{type = command_button_clicked}}, State) ->

	%% Find ETracerConfig record
	Rec = case etracer:get_etracer_config_record(State#state.eTracerConfigName) of
		{ok, RecT} ->
			%% Record found
			RecT;
		Else ->
			Else
	end,
	
	%%error_logger:info_report(["Event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}, {eTracerConfigRec, Rec}]),

	case Id of
		?WX_BUTTON_ID_SAVETOTRACEPATTERN ->
			%% Save all selected Modules/Functions into Trace Pattern FilterBox
			
			%% Get all selection in module FilterBox first
			case wxFilterBox:filterBoxCtrl_GetSelectedItems(?MODULE_SELECTION_SERVER(Rec#rETracerConfig.name)) of
				{ok, Modules} ->
					case Modules of
						[Mod] ->
							%% Only one module had been selected. Check there are functions selected or not. If they are not
							%% selected means the all exported/not exported functions will involved in the trace.
							case wxFilterBox:filterBoxCtrl_GetSelectedItems(?FUNCTION_SELECTION_SERVER(Rec#rETracerConfig.name)) of
								{ok, Functions} ->
									case Functions of
										[] ->
											%% None of functions are selected.
											append_to_trace_pattern(Rec#rETracerConfig.name, Mod);
										_->	%% Some functions had been selected
											[begin
												case string:rstr(Fun, ?FUNCTION_ARITY_SEPARATOR) of
													0 ->
														%% Upps, ?FUNCTION_ARITY_SEPARATOR char does not found
														ok;
													I ->
														%% I is the last position of ?FUNCTION_ARITY_SEPARATOR char.
														%% Copy subsctring from 1 to I
														FuncName = string:sub_string(Fun, 1, I-1),
														Arity = string:sub_string(Fun, I+1, string:len(Fun)),
														append_to_trace_pattern(Rec#rETracerConfig.name, 
                                                                                Mod, FuncName, Arity)
												end
											 end || Fun <- Functions]
									end;
								{error, Reason} ->
									error_logger:error_report(["Error occured when fetching selected items in Function FilterBox", {reason, Reason}, {module, ?MODULE}, {line, ?LINE}]),
									ok
							end;
						_->	%% More than one module had been selected
							[begin
								 append_to_trace_pattern(Rec#rETracerConfig.name, Mod)
							 end || Mod <- Modules]
					end,
					
					%% Save Trace pattern in MNESIA too
					%% TODO
					case wxFilterBox:filterBoxCtrl_GetItems(?TRACEPATTERN_SELECTION_SERVER(Rec#rETracerConfig.name)) of
						{ok, Items} ->
							set_trace_patern(Rec#rETracerConfig.name, Items);
						_->	do_nothing
					end,

					{noreply, State};
				
				{error, Reason} ->
					error_logger:error_report(["Error occured when fetching selected items in Module FilterBox", {reason, Reason}, {module, ?MODULE}, {line, ?LINE}]),
					{noreply, State}
			end;
		
		?WX_BUTTON_ID_DELETEINTRACEPATTERN ->
			DialogText = "Are you sure you want to delete?",
			PressedButton = wxMessageDialog:showModal(wxMessageDialog:new(State#state.win, DialogText,
																		  [{style, ?wxYES_NO bor ?wxICON_QUESTION bor ?wxSTAY_ON_TOP},
																		   {caption, DialogText}])),
			case PressedButton of
				?wxID_NO ->
					{noreply, State};
				?wxID_YES ->
					TracePatternSelectionServer = ?TRACEPATTERN_SELECTION_SERVER(Rec#rETracerConfig.name),
					Items = case wxFilterBox:filterBoxCtrl_GetSelectedItems(TracePatternSelectionServer) of
								{ok, ItemsT} ->
									ItemsT;
								_->	[]
							end,
					%% Remove all selected items in Trace Pattern FilterBox
					case wxFilterBox:filterBoxCtrl_DeleteSelectedItems(?TRACEPATTERN_SELECTION_SERVER(Rec#rETracerConfig.name)) of
						ok ->
							delete_trace_pattern(Rec#rETracerConfig.name, Items),
							{noreply, State};
						{error, Reason} ->
							error_logger:error_report(["Error occured when deleting selected items in Trace Pattern FilterBox", {reason, Reason}]),
							{noreply, State}
					end
			end;
		
		_->	%% Not used yet
			{noreply, State}
	end;

handle_event(_WXEvent = #wx{id = Id, 
						   obj = _Obj,
						   event = #wxCommand{type = command_checkbox_clicked,
											  commandInt = CheckedIn}}, State) ->
	
	%%error_logger:info_report(["Event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
	
	IsCheckedIn = case CheckedIn of
					  0 -> false;
					  1 -> true
				  end,
	{FlagType, Flag} = case Id of
						   ?WX_CHECKBOX_ID_TRACE_FLAG_MESSAGE ->
							   {trace_flag, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.message)};
						   
						   ?WX_CHECKBOX_ID_TRACE_FLAG_CALL ->
							   {trace_flag, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.call)};
						   
						   ?WX_CHECKBOX_ID_TRACE_FLAG_PROC ->
							   {trace_flag, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.procs)};
						   
						   ?WX_CHECKBOX_ID_TRACE_FLAG_RECEIVE ->
							   {trace_flag, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.'receive')};
						   
						   ?WX_CHECKBOX_ID_TRACE_FLAG_SEND ->
							   {trace_flag, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.send)};
						   
						   ?WX_CHECKBOX_ID_MATCHSPEC_FLAG_MESSAGE ->
							   {trace_matchspecification_flag, ?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.message)};
						   
						   ?WX_CHECKBOX_ID_MATCHSPEC_FLAG_PROCESSDUMP ->
							   {trace_matchspecification_flag, ?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.process_dump)};
						   
						   ?WX_CHECKBOX_ID_MATCHSPEC_FLAG_RETURNTRACE ->
							   {trace_matchspecification_flag, ?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.return_trace)}
						   end,
	
	%% Save Trace Flag in the database
	case etracer:get_etracer_config_record(State#state.eTracerConfigName) of
		{ok, Rec} ->
			%% Record found
			NewRec = case IsCheckedIn of
						 true ->
							 %% Set the flag
							 
							 case FlagType of
								 trace_flag ->
									 Rec#rETracerConfig{trace_flags = lists:usort(lists:merge(Rec#rETracerConfig.trace_flags, [Flag]))};
								 trace_matchspecification_flag ->
									 Rec#rETracerConfig{trace_match_spec_flags = lists:usort(lists:merge(Rec#rETracerConfig.trace_match_spec_flags, [Flag]))}
							 end;
						 
						 _->	%% Unset the flag
							 case FlagType of
								 trace_flag ->
									 Rec#rETracerConfig{trace_flags = lists:delete(Flag, Rec#rETracerConfig.trace_flags)};
								 trace_matchspecification_flag ->
									 Rec#rETracerConfig{trace_match_spec_flags = lists:delete(Flag, Rec#rETracerConfig.trace_match_spec_flags)}
							 end
					 end,
			
			etracer:set_etracer_config_record(NewRec);
			
		Else ->
			Else
	end,
	
	%%error_logger:info_report(["ETracerConforRec after set/unset Flags", {rec, etracer:get_etracer_config_record(State#state.eTracerConfigName)}]),
	
	{noreply, State};

handle_event(Ev,State) ->
    io:format("~p Got event ~p ~n",[?MODULE, Ev]),
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
%% Purpose: Convert process rSTATE when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% --------------------------------------------------------------------
%% Local Functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Create CheckBox area
%% Input:
%%		Panel			:	wxWindow(), the panel where to be put checkboxes
%%		Label			:	string, title of the CheckBox area
%%		CheckBoxList	:	list of tuple, the list of CheckBoxes to be create
%% Output:
%%		{Sizer, ObjIdList}	:	id of Sizer of CheckBox "area"	
%% --------------------------------------------------------------------
create_checkboxes(Panel, Label, CheckBoxList) ->
	%% Create an own sizer
    CheckSizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, Label}]),
    
	%% Create CheckBoxes
	CheckBoxObjList = [begin
						   {CheckBoxType, wxCheckBox:new(Panel, CheckBoxId, erlang:atom_to_list(CheckBoxType), [])}
					   end || {CheckBoxId, CheckBoxType} <- CheckBoxList],
	
	Fun = fun({_, Obj}) ->
				  wxCheckBox:connect(Obj, command_checkbox_clicked),
				  wxSizer:add(CheckSizer, Obj)
		  end,
	wx:foreach(Fun, CheckBoxObjList),
	
	%% Returns with sizer
    {CheckSizer, CheckBoxObjList}.

%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
create_top_panel(ETracerConfigName, Parent, Label) ->
	Panel = wxPanel:new(Parent, []),
	
	Sizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, Label}]),
	
	%% Module/Function selection
	ModuleFunctionSelectionSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel, [{label, ""}]),
	
	%% Setup Action list to be use in Module Selection FiterBox
	ModuleSelectionServer = ?MODULE_SELECTION_SERVER(ETracerConfigName),
	ActionListModuleSelectionPanel = [{#rFILTERBOX_ACTIONS.command_listbox_selected, 
                                       {?MODULE, notify, [self(), 
                                                          {'MODULE_SELECTION', #rFILTERBOX_ACTIONS.command_listbox_selected, give_selected_items}]}}],
	ModuleSelectionPanel = wxFilterBox:start(ModuleSelectionServer, [{parent, Panel}, {label, "Module selection"}, {action_list, ActionListModuleSelectionPanel}]),
	
	FunctionSelectionServer = ?FUNCTION_SELECTION_SERVER(ETracerConfigName),
	ActionListFunctionSelectionPanel = [{#rFILTERBOX_ACTIONS.command_listbox_selected, {?MODULE, notify, [self(), {'FUNCTION_SELECTION', #rFILTERBOX_ACTIONS.command_listbox_selected, give_selected_items}]}}],
	FunctionSelectionPanel = wxFilterBox:start(FunctionSelectionServer, [{parent, Panel}, {label, "Function selection"}, {action_list, ActionListFunctionSelectionPanel}]),
	
	wxSizer:add(ModuleFunctionSelectionSizer, ModuleSelectionPanel, [{flag, ?wxEXPAND},{proportion, 1}]),
	wxSizer:add(ModuleFunctionSelectionSizer, FunctionSelectionPanel, [{flag, ?wxEXPAND},{proportion, 1}]),
	wxSizer:add(Sizer, ModuleFunctionSelectionSizer, [{proportion, 1}, {flag, ?wxEXPAND}]),
	
	wxSizer:addSpacer(Sizer, 5),
	
	%% Create a button for "saving" selected module(s)/function(s) to Trace Pattern list
	SaveToTracePatternButtonObj = wxButton:new(Panel, ?WX_BUTTON_ID_SAVETOTRACEPATTERN, [{label, "Save to Trace Pattern"}]),
	wxButton:connect(SaveToTracePatternButtonObj, command_button_clicked),
	wxSizer:add(Sizer, SaveToTracePatternButtonObj, [{border, 5}, {flag, ?wxEXPAND}]),
	
	%% Trace Pattern
	TracePatternSelectionSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel, [{label, ""}]),
	
	%% Setup extra buttons to be use for Trace Pattern FilterBox.
	TracePatternSelectionServer = ?TRACEPATTERN_SELECTION_SERVER(ETracerConfigName),
	TracePatternSelectionPanel = wxFilterBox:start(TracePatternSelectionServer, [{parent, Panel}, {label, "Trace patterns"}]),
	wxSizer:add(TracePatternSelectionSizer, TracePatternSelectionPanel, [{flag, ?wxEXPAND},{proportion, 1}]),
	wxSizer:add(Sizer, TracePatternSelectionSizer, [{proportion, 1}, {flag, ?wxEXPAND}]),
	
	wxSizer:addSpacer(Sizer, 5),
	
	%% Create a button for "delete" selected module(s)/function(s) in Trace Pattern list
	DeleteInTracePatternButtonObj = wxButton:new(Panel, ?WX_BUTTON_ID_DELETEINTRACEPATTERN, [{label, "Delete Trace Pattern(s)"}]),
	wxButton:connect(DeleteInTracePatternButtonObj, command_button_clicked),
	wxSizer:add(Sizer, DeleteInTracePatternButtonObj, [{border, 5}, {flag, ?wxEXPAND}]),
	
	wxPanel:setSizer(Panel, Sizer),
	
	Panel.

%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
create_bottom_panel(Parent, Label) ->
	Panel = wxPanel:new(Parent, []),
	
	Sizer = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel, [{label, Label}]),
	
	%% Create "Trace Flags" section
	{TraceFlagsSizer, TraceFlagObjIdList} = create_checkboxes(Panel, "Trace Flags", [{?WX_CHECKBOX_ID_TRACE_FLAG_CALL, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.call)},
																					 {?WX_CHECKBOX_ID_TRACE_FLAG_MESSAGE, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.message)},
																					 {?WX_CHECKBOX_ID_TRACE_FLAG_PROC, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.procs)},
																					 {?WX_CHECKBOX_ID_TRACE_FLAG_RECEIVE, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.'receive')},
																					 {?WX_CHECKBOX_ID_TRACE_FLAG_SEND, ?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.send)}
																					]),
	%% Create "Match Specification" area
	MatchSpecSizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, "Match Specification"}]),
	%%MatchSpecEntryObj = wxTextCtrl:new(Panel, ?WX_TEXTCTRL_ID_MATCH_SPEC, [{value, ""}, 
	%%																	   {style, ?wxTE_READONLY}]),
	%%wxSizer:add(MatchSpecSizer, MatchSpecEntryObj),
	wxSizer:add(Sizer, TraceFlagsSizer),
	
	{MatchSpecFlagsSizer, MatchSpecFlagsObjList} = create_checkboxes(Panel, " Flags", [{?WX_CHECKBOX_ID_MATCHSPEC_FLAG_MESSAGE, ?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.message)},
																					   {?WX_CHECKBOX_ID_MATCHSPEC_FLAG_PROCESSDUMP, ?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.process_dump)},
																					   {?WX_CHECKBOX_ID_MATCHSPEC_FLAG_RETURNTRACE, ?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.return_trace)}
																					  ]),
	wxSizer:add(MatchSpecSizer, MatchSpecFlagsSizer),
	wxSizer:add(Sizer, MatchSpecSizer, []),
	
	wxPanel:setSizer(Panel, Sizer),
	
	{Panel, lists:append([{trace_flag, TraceFlagObjIdList}], [{trace_matchspecification_flag, MatchSpecFlagsObjList}])}.

%% --------------------------------------------------------------------
%% Append item in Trace Pattern FilterBox
%% Input:
%%		ETracerConfigName	:	string
%%		Module				:	string
%%		Function			:	string | list 
%%		Arity				:	a number as a string
%% Output:
%%		ok | {error, Reason}
%% --------------------------------------------------------------------
append_to_trace_pattern(ETracerConfigName, Module) ->
    append_to_trace_pattern(ETracerConfigName, Module, '_').

append_to_trace_pattern(ETracerConfigName, Module, Function) ->
    append_to_trace_pattern(ETracerConfigName, Module, Function, '_').

append_to_trace_pattern(ETracerConfigName, Module, Function, Arity) ->
	TracePattern = generate_trace_pattern_text(Module, Function, Arity),
	
	TracePatternSelectionServer = ?TRACEPATTERN_SELECTION_SERVER(ETracerConfigName),
	
	case wxFilterBox:filterBoxCtrl_FindString(TracePatternSelectionServer, TracePattern) of
		false ->
			wxFilterBox:filterBoxCtrl_AppendItems(TracePatternSelectionServer, [TracePattern]),
			ok;
		_->	%% Already there
			ok
	end.
	
%% --------------------------------------------------------------------
%% Create Trace Pattern text for the FilterBox
%% Input:
%%		Module	:	string
%%		Function:	string | list 
%%		Arity	:	a number as a string
%% Output:
%%		Text	:	string
%% --------------------------------------------------------------------
generate_trace_pattern_text(Module, '_', '_') ->
    generate_trace_pattern_text(Module, "_", "_");
generate_trace_pattern_text(Module, Function, Arity) ->
    Module++?MODULE_FUNCTION_SEPARATOR++Function++?FUNCTION_ARITY_SEPARATOR++Arity.

%% --------------------------------------------------------------------
%% Save Trace Pattern into MNESIA
%% Input:
%%		ETracerConfigName	:	string
%%		TracePatternList	:	list of string, items in "TracePatternSelectionServer" FilterBox
%% Output:
%%		ok | {error, Reason}
%% --------------------------------------------------------------------
set_trace_patern(ETracerConfigName, TracePatternList) ->
	%% Get record of ETracerConfigName first
	case etracer:get_etracer_config_record(ETracerConfigName) of
		{ok, Rec} ->
			%% Convert string based pattern to erlang term. Merge list already saved with new.
			etracer:set_etracer_config_record(Rec#rETracerConfig{trace_pattern = lists:usort(lists:merge(Rec#rETracerConfig.trace_pattern, convert_string_based_trace_pattern(TracePatternList)))});
		{error, Reason} ->
			{error, Reason}
	end.

%% --------------------------------------------------------------------
%% Delete Trace Pattern in MNESIA
%% Input:
%%		ETracerConfigName	:	string
%%		TracePatternList	:	list of string, deleted items in "TracePatternSelectionServer" FilterBox
%% Output:
%%		ok | {error, Reason}
%% --------------------------------------------------------------------
delete_trace_pattern(ETracerConfigName, TracePatternList) ->
	%% Get record of ETracerConfigName first
	case etracer:get_etracer_config_record(ETracerConfigName) of
		{ok, Rec} ->
			%% Convert string based pattern to erlang term.
			L = convert_string_based_trace_pattern(TracePatternList),
			
			%% Delete these in Rec#rETracerConfig.trace_pattern
			RemainingList = delete_trace_pattern_loop(L, Rec#rETracerConfig.trace_pattern),
			
			%% Save changes in MNESIA
			etracer:set_etracer_config_record(Rec#rETracerConfig{trace_pattern = RemainingList});
			
		{error, Reason} ->
			{error, Reason}
	end.

delete_trace_pattern_loop([], RemainingList) ->
	RemainingList;
delete_trace_pattern_loop([H|T], RemainingList) ->
	delete_trace_pattern_loop(T, lists:delete(H, RemainingList)).
	
%% --------------------------------------------------------------------
%% Convert string based Trace Pattern to erlang term().
%% Input:
%%		TracePatternList_StringBased	:	list of string
%% Output:
%%		TracePatternList				:	list of tuple, [{M,F,A}, ...]
%% --------------------------------------------------------------------
convert_string_based_trace_pattern(TracePatternList_StringBased) ->
	convert_string_based_trace_pattern_loop(TracePatternList_StringBased, []).

convert_string_based_trace_pattern_loop([], TracePatternList) ->
	TracePatternList;
convert_string_based_trace_pattern_loop([H|T], TracePatternList) ->
	%% Split the string by ?MODULE_FUNCTION_SEPARATOR
	{M,F,A} = case re:split(H, ?MODULE_FUNCTION_SEPARATOR) of
				  [ModT,FuncAndArityT] ->
					  Mod = erlang:binary_to_list(ModT),
					  FuncAndArity = erlang:binary_to_list(FuncAndArityT),
					  case re:split(FuncAndArity, ?FUNCTION_ARITY_SEPARATOR) of
						  [FuncT, ArityT] ->
							  Func = erlang:list_to_atom(erlang:binary_to_list(FuncT)),
							  Arity = case erlang:binary_to_list(ArityT) of
                                          "_" ->
                                              '_';
                                          ArityString-> erlang:list_to_integer(ArityString)
                                      end,
							  
							  {erlang:list_to_atom(Mod), Func, Arity};
						  _->
							  %% More that one ?FUNCTION_ARITY_SEPARATOR found, thus have to find the last.
							  case string:rstr(FuncAndArity, ?FUNCTION_ARITY_SEPARATOR) of
								  0 ->
									  %% Upps, ?FUNCTION_ARITY_SEPARATOR char does not found
									  error_logger:error_report(["Error occured when convert Trace Pattern to string", {trace_patter, H}]),
									  ok;
								  I ->
									  %% I is the last position of ?FUNCTION_ARITY_SEPARATOR char.
									  %% Copy subsctring from 1 to I
									  Func = string:sub_string(FuncAndArity, 1, I-1),
									  Arity = string:sub_string(FuncAndArity, I+1, string:len(FuncAndArity)),
									  {erlang:list_to_atom(Mod), erlang:list_to_atom(Func), erlang:list_to_integer(Arity)}
							  end
					  end
			  end,
	NewTracePatternList = lists:append(TracePatternList, [{M,F,A}]),
	convert_string_based_trace_pattern_loop(T, NewTracePatternList).

%% --------------------------------------------------------------------
%% Convert Trace Pattern to string for wxFilterBox
%% Input:
%%		TracePatternList				:	list of tuple, [{M,F,A}, ...]
%% Output:
%%		TracePatternList_StringBased	:	list of string
%% --------------------------------------------------------------------
convert_trace_pattern_to_string(TracePatternList) ->
	convert_trace_pattern_to_string_loop(TracePatternList, []).

convert_trace_pattern_to_string_loop([], TracePatternList_StringBased) ->
	TracePatternList_StringBased;
convert_trace_pattern_to_string_loop([{M,F,'_'}|T], TracePatternList_StringBased) ->
    convert_trace_pattern_to_string_loop(T, lists:append(TracePatternList_StringBased, [erlang:atom_to_list(M)++
                                                                                            ?MODULE_FUNCTION_SEPARATOR++
                                                                                            erlang:atom_to_list(F)++
                                                                                            ?FUNCTION_ARITY_SEPARATOR++
                                                                                            "_"]));
convert_trace_pattern_to_string_loop([{M,F,A}|T], TracePatternList_StringBased) ->
	convert_trace_pattern_to_string_loop(T, lists:append(TracePatternList_StringBased, [erlang:atom_to_list(M)++
                                                                                            ?MODULE_FUNCTION_SEPARATOR++
                                                                                            erlang:atom_to_list(F)++
                                                                                            ?FUNCTION_ARITY_SEPARATOR++
                                                                                            erlang:integer_to_list(A)])).

%% --------------------------------------------------------------------
%% Get the list of exported and not exported functions of module.
%% Input:
%%		ErlangNode	:	atom
%%		Module		:	atom
%% Output:
%%		FuncList	:	list of string
%% --------------------------------------------------------------------
get_functions(ErlangNode, Module) ->
	L1 = case etracer:get_exported_functions(ErlangNode, Module) of
			 {ok, ExportedList} ->
				 ExportedList;
			 _-> []
		 end,
	L11 = get_functions_loop(L1, []),
	
	L2 = case etracer:get_not_exported_functions(ErlangNode, Module) of
			 {ok, NotExportedList} ->
				 NotExportedList;
			 _-> []
		 end,
	L22 = get_functions_loop(L2, []),
	
	lists:append(L11, L22).

get_functions_loop([], Result) ->
	Result;
get_functions_loop([{Func,Arity}|T], Result) ->
	F = erlang:atom_to_list(Func)++?FUNCTION_ARITY_SEPARATOR++erlang:integer_to_list(Arity),
	get_functions_loop(T, lists:append(Result, [F])).