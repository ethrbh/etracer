%% Author: ETHRBH
%% Created: Jun 25, 2012
%% Description: TODO: Add description to wxListBoxExt
-module(wxFilterBox).

%% --------------------------------------------------------------------
%% Behaviour
%% --------------------------------------------------------------------
-behaviour(wx_object).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include_lib("wx/include/wx.hrl").
-include_lib("wx/src/wxe.hrl").
-include("../include/wxFilterBox.hrl").

%% --------------------------------------------------------------------
%% Exported Functions
%% --------------------------------------------------------------------
-export([
		 filterBoxCtrl_GetItems/1,
		 filterBoxCtrl_AppendItems/2,
		 filterBoxCtrl_Clear/1,
		 filterBoxCtrl_GetSelectedItems/1,
		 filterBoxCtrl_DeleteSelectedItems/1,
		 filterBoxCtrl_FindString/2
		]).



%% --------------------------------------------------------------------
%% WX behaviour exports
%% --------------------------------------------------------------------
-export([start/1, start/2, start_link/1, start_link/2, stop/1, init/1,
		 format/3, 
		 handle_cast/2, handle_call/3, handle_info/2, handle_event/2,
		 terminate/2,  
		 code_change/3]).

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------
-record(state, {
				config,
				obj_list,
				listbox_items
			   }).

%% --------------------------------------------------------------------
%% Defines
%% --------------------------------------------------------------------
-define(DEFAULT_ITEMS_FOR_TEST, [begin "item_"++erlang:integer_to_list(I) end || I <- lists:seq(0, 100)]).

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% @spec filterBoxCtrl_GetItems(Server) -> {ok, List} | {error, Reason}
%% Server	=	pid()
%% @doc
%% Give the list of items in the listbox.
%% @end
%% --------------------------------------------------------------------
filterBoxCtrl_GetItems(Server) ->
	case check_server_accessibility(Server) of
		true ->
			case gen_server:call(Server, {filterBoxCtrl_GetItems}, ?WX_FILTERBOX_GENSERVER_CALL_TO) of
				{ok, List} ->
					{ok, List};
				{error, Reason} ->
					{error, Reason}
			end;
		_->	{error, "server is not alive"}
	end.

%% --------------------------------------------------------------------
%% @spec filterBoxCtrl_AppendItems(Server, Items:list() -> ok | {error, Reason}
%% @doc
%% @end
%% --------------------------------------------------------------------
filterBoxCtrl_AppendItems(Server, Items) ->
	case check_server_accessibility(Server) of
		true ->
			case gen_server:call(Server, {filterBoxCtrl_AppendItems, Items}, ?WX_FILTERBOX_GENSERVER_CALL_TO) of
				ok ->
					ok;
				{error, Reason} ->
					{error, Reason}
			end;
		_->	{error, "server is not alive"}
	end.

%% --------------------------------------------------------------------
%% @spec filterBoxCtrl_Clear(Server) -> ok | {error, Reason}
%% @doc
%% Delete all items in listbox.
%% @end
%% --------------------------------------------------------------------
filterBoxCtrl_Clear(Server) ->
	case check_server_accessibility(Server) of
		true ->
			case gen_server:call(Server, {filterBoxCtrl_Clear}, ?WX_FILTERBOX_GENSERVER_CALL_TO) of
				ok ->
					ok;
				{error, Reason} ->
					{error, Reason}
			end;
		_->	{error, "server is not alive"}
	end.

%% --------------------------------------------------------------------
%% @spec filterBoxCtrl_GetSelectedItems(Server) -> {ok, List} | {error, Reason}
%% @doc
%% Give selected items in listbox.
%% @end
%% --------------------------------------------------------------------
filterBoxCtrl_GetSelectedItems(Server) ->
	case check_server_accessibility(Server) of
		true ->
			case gen_server:call(Server, {filterBoxCtrl_GetSelectedItems}, ?WX_FILTERBOX_GENSERVER_CALL_TO) of
				{ok, Items} ->
					{ok, Items};
				{error, Reason} ->
					{error, Reason}
			end;
		_->	{error, "server is not alive"}
	end.

%% --------------------------------------------------------------------
%% @spec filterBoxCtrl_DeleteSelectedItems(Server) -> ok | {error, Reason}
%% @doc
%% Delete all selected items in listbox.
%% @end
%% --------------------------------------------------------------------
filterBoxCtrl_DeleteSelectedItems(Server) ->
	case check_server_accessibility(Server) of
		true ->
			case gen_server:call(Server, {filterBoxCtrl_DeleteSelectedItems}, ?WX_FILTERBOX_GENSERVER_CALL_TO) of
				ok ->
					ok;
				{error, Reason} ->
					{error, Reason}
			end;
		_->	{error, "server is not alive"}
	end.

%% --------------------------------------------------------------------
%% @spec filterBoxCtrl_FindString(Server, String) -> boolean()
%% @doc
%% Find string in the FilterBox
%% @end
%% --------------------------------------------------------------------
filterBoxCtrl_FindString(Server, String) ->
	case check_server_accessibility(Server) of
		true ->
			case gen_server:call(Server, {filterBoxCtrl_FindString, String}, ?WX_FILTERBOX_GENSERVER_CALL_TO) of
				true ->
					true;
				_->	false
			end;
		_->	false
	end.

%% --------------------------------------------------------------------
%% @spec start(Server) -> Ref:wxWindow() | {error, Reason}
%% Server	=	atom, name of the process to be start
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start(Server) ->
	start(Server, []).

%% --------------------------------------------------------------------
%% @spec start(Server, Config) -> Ref:wxWindow() | {error, Reason}
%% Server	=	atom, name of the process to be start
%% Config	=	list()
%% @doc
%% Start WX application
%% 
%% Here is the description of Config. The Config is a list of tuple.
%% There parameters for controlling behaviour of wxFilterBox.
%%	{parent, <PARENT>}								=	parent Obj to where wxFilterBox Obj will belongs
%%	{button_list, [{ButtonId, ButtonLabel},...]}	=	list of extra buttons if they are need. Check
%%														usable Buttons in #rFILTERBOX_BUTTONS{}
%%  {action_list, [{ActionType, MFA}, ...]}			=	list of Actions to be done when Action is happened
%%														ActionType	-	atom, name of the action, see #rFILTERBOX_ACTIONS{}
%%														MFA			-	tuple of MFA to be callback
%%														 
%% @end
%% --------------------------------------------------------------------
start(Server, Config) ->
	case whereis(Server) of
		P when is_pid(P) ->
			%%{error, "Server is already running"};
			catch erlang:exit(P, kill),
			start(Server, Config);
		_->
			case catch wx_object:start({local, Server}, ?MODULE, Config, []) of
				Ref when is_record(Ref, wx_ref) ->
					Ref;
				Error ->
					Error
			end
	end.

%% --------------------------------------------------------------------
%% @spec start(Server) -> Ref:wxWindow() | {error, Reason}
%% Server	=	atom, name of the process to be start
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start_link(Server) ->
	start_link(Server, []).

%% --------------------------------------------------------------------
%% @spec start(Server, Config) -> Ref:wxWindow() | {error, Reason}
%% Server	=	atom, name of the process to be start
%% Config	=	term()
%% @doc
%% Start WX application
%% @end
%% --------------------------------------------------------------------
start_link(Server, Config) ->
	case catch wx_object:start_link({local, Server}, ?MODULE, Config, []) of
		Ref when is_record(Ref, wx_ref) ->
			Ref;
		Error ->
			Error
	end.

%% --------------------------------------------------------------------
%% @spec stop(Server) -> ok | {error, Reason}
%% Server	=	atom, name of the process to be start
%% @doc
%% Stop WX process
%% @end
%% --------------------------------------------------------------------
stop(Server) ->
	case whereis(Server) of
		P when is_pid(P) ->
			case wx_object:call(Server, {stop}, ?WX_FILTERBOX_GENSERVER_CALL_TO) of
				ok ->
					ok;
				{error, Reason} ->
					{error, Reason}
			end;
		_->
			ok
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
%% @spec init(Config) -> {Frame, #state{}}
%% Config	=	list of tuple
%% @doc
%% Init WX server
%% @end
%% --------------------------------------------------------------------
init(Config) ->
	{Panel, ObjList} = create(Config),
	
%% 	Items = case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, ObjList) of
%% 				{value, {_, ListBoxId}} ->
%% 					%% Clear all items in listbox
%% 					do_filterBoxCtrl_Clear(ListBoxId),
%% 					
%% 					%% Set default items in listbox
%% 					do_filterBoxCtrl_AppendItems(ListBoxId, ?DEFAULT_ITEMS_FOR_TEST),
%% 					?DEFAULT_ITEMS_FOR_TEST;
%% 				_->	[]
%% 			end,
	
	Items = [],
	{Panel, #state{config = Config, obj_list = ObjList, listbox_items = Items}}.

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
handle_call({filterBoxCtrl_GetItems}, _From, State) ->
	%% Find listbox id
	case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
		{value, {_, ListBoxId}} ->
			Items = do_ListBoxCtrl_GetItems(ListBoxId),
			{reply, {ok, Items} ,State};
		false ->
			{reply, {error, "ListBox does not found"}, State}
	end;

handle_call({filterBoxCtrl_AppendItems, Items}, _From, State) ->
	case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
		{value, {_, ListBoxId}} ->
			case do_filterBoxCtrl_AppendItems(ListBoxId, Items) of
				ok ->
					{reply, ok, State#state{listbox_items = lists:append(State#state.listbox_items, Items)}};
				{error, Reason} ->
					{reply, {error, Reason}, State}
			end;
		false ->
			{reply, {error, "ListBox does not found"}, State}
	end;

handle_call({filterBoxCtrl_Clear}, _From, State) ->
	case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
		{value, {_, ListBoxId}} ->
			case do_filterBoxCtrl_Clear(ListBoxId) of
				ok ->
					{reply, ok, State#state{listbox_items = []}};
				{error, Reason} ->
					{reply, {error, Reason}, State}
			end;
		false ->
			{reply, {error, "ListBox does not found"}, State}
	end;

handle_call({filterBoxCtrl_GetSelectedItems}, _From, State) ->
	case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
		{value, {_, ListBoxId}} ->
			case do_filterBoxCtrl_GetSelectedItems(ListBoxId) of
				{ok, Items} ->
					
					%% {get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.filter_entry_id), FilterEntry}
					%% If Items is an empty list, returns with the
					%% entered text in the Entry onject. This is usefule if the Node is DOWN and the tool could not fetch the modules but we would like to setting up the tracemeasure.
					NewItems = case Items of
								   [] ->
									   case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.filter_entry_id), 1, State#state.obj_list) of
										   {value, {_, FilterEntry}} ->
											   case wxTextCtrl:getValue(FilterEntry) of
												   [] ->
													   [];
												   Text when is_list(Text) ->
													   [Text];
												   _-> []
											   end;
										   _-> []
									   end;
								   
								   _-> Items
							   end,
							
					{reply, {ok, NewItems}, State};
				
				{error, Reason} ->
					{reply, {error, Reason}, State}
			end;
		false ->
			{reply, {error, "ListBox does not found"}, State}
	end;

handle_call({filterBoxCtrl_DeleteSelectedItems}, _From, State) ->
	case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
		{value, {_, ListBoxId}} ->
			do_filterBoxCtrl_DeleteSelectedItems(ListBoxId),
			{reply, ok, State#state{listbox_items = do_ListBoxCtrl_GetItems(ListBoxId)}};
		false ->
			{reply, {error, "ListBox does not found"}, State}
	end;

handle_call({filterBoxCtrl_FindString, String}, _From, State) ->
	case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
		{value, {_, ListBoxId}} ->
			Result = case wxListBox:findString(ListBoxId, String) of
						 -1 ->
							 false;
						 _-> true
					 end,
			{reply, Result, State};
		false ->
			{reply, false, State}
	end;

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
handle_info(_Info, State) ->
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_event/2
%% Description: %% Async Events are handled in handle_event as in handle_info
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_event(_WXEvent = #wx{obj  = _Checkbox,
							event = #wxCommand{type = command_checkbox_clicked,
											   commandInt = Int}},
			 State = #state{config = _Config}) ->
	
	case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
		{value, {_, ListBoxId}} ->
			case Int of
				0 -> 
					%%error_logger:info_report(["Checkbox unselected", {module, ?MODULE}, {line, ?LINE}]),
					do_ListBoxCtrl_UnselectAllItems(ListBoxId),
					{noreply, State};
				1 -> 
					%%error_logger:info_report(["Checkbox selected", {module, ?MODULE}, {line, ?LINE}]),
					
					do_ListBoxCtrl_SelectAllItems(ListBoxId),
					
					case proplists:get_value(action_list, State#state.config) of
						undefined ->
							%% No actions to be done
							{noreply, State};
						[] ->
							%% No actions to be done
							{noreply, State};
						ActionList ->
							[begin 
								 error_logger:info_report(["Action", {action, {{Action, MFA}}}]),
								 case {Action, MFA} of
									 {#rFILTERBOX_ACTIONS.command_listbox_selected, _} ->
										 %% This is the interested Action for ListBox
										 
										 case MFA of
											 {M, F, [SendTo, {MsgId, #rFILTERBOX_ACTIONS.command_listbox_selected, give_selected_items}]} ->
												 %% Call MFA for sending selected items
												 erlang:apply(M, F, [SendTo, {MsgId, #rFILTERBOX_ACTIONS.command_listbox_selected, all}]);
											 _-> do_nothing
										 end
								 end
							 end || {Action, MFA} <- ActionList],
							
							{noreply, State}
					end
			end;
		false ->
			{noreply, State}
	end;

handle_event(_WXEvent = #wx{id = Id, 
							obj = Obj,
							event = #wxCommand{type = command_text_updated}}, State) ->
	%%error_logger:info_report(["Event received", {module, ?MODULE}, {line, ?LINE}, {event, WXEvent}]),
	
	case Id of
		?WX_FILTERBOX_ENTRY_ID ->
			case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
				{value, {_, ListBoxId}} ->
					Text = wxTextCtrl:getValue(Obj),
					
					%% Unset "Select all" checkbox
					case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.select_all_check_box_id), 1, State#state.obj_list) of
						{value, {_, CheckBoxId}} ->
							wxCheckBox:setValue(CheckBoxId, false);
						_->	do_nothing
					end,
					
					%% Filter the items in listbox
					do_ListBoxCtrl_FilterItems(ListBoxId, Text, State#state.listbox_items),
					{noreply, State};
				
				_->	{noreply, State}
			end;
		
		_-> {noreply, State}
	end;

handle_event(_WXEvent = #wx{id = _Id,
				 obj = _Obj,
				 event = #wxCommand{type = command_listbox_selected}}, State) ->
%% =INFO REPORT==== 26-Jun-2012::22:28:38 ===
%%     "Unexpected event received"
%%     event: {wx,1,
%%                {wx_ref,353,wxListBox,[]},
%%                [],
%%                {wxCommand,command_listbox_selected,"beam_lib",4,0}}
%%     module: wxFilterBox
%%     line: 403
	
	%%error_logger:info_report(["Event received", {event, WXEvent}, {module, ?MODULE}, {line, ?LINE}]),
	
	case proplists:get_value(action_list, State#state.config) of
		undefined ->
			%% No actions to be done
			{noreply, State};
		[] ->
			%% No actions to be done
			{noreply, State};
		ActionList ->
			[begin 
				 error_logger:info_report(["Action", {action, {{Action, MFA}}}]),
				 case {Action, MFA} of
					 {#rFILTERBOX_ACTIONS.command_listbox_selected, _} ->
						 %% This is the interested Action for ListBox
						 
						 %% Item or items are selected. Inform setup_tracemeasure process.
						 case lists:keysearch(get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), 1, State#state.obj_list) of
							 {value, {_, ListBoxId}} ->
								 case do_filterBoxCtrl_GetSelectedItems(ListBoxId) of
									 {ok, Items} ->
										 %%io:format("Selected items: ~p~n", [Items]),
										 case MFA of
											 {M, F, [SendTo, {MsgId, #rFILTERBOX_ACTIONS.command_listbox_selected, give_selected_items}]} ->
												 %% Call MFA for sending selected items
												 SelectedItems = [erlang:list_to_atom(Item) || Item <- Items],
												 %%error_logger:info_report(["Selected items", {items, SelectedItems}]),
												 erlang:apply(M, F, [SendTo, {MsgId, #rFILTERBOX_ACTIONS.command_listbox_selected, SelectedItems}]);
											 _-> do_nothing
										 end;
									 _-> do_nothing
								 end;
							 _-> do_nothing
						 end
				 end
			 end || {Action, MFA} <- ActionList],
			
			{noreply, State}
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
	%%error_logger:info_report(["terminate", {reason, Reason}, {state, State}, {module, ?MODULE}, {line, ?LINE}]),
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
%% @spec create(Config) -> {Panel, Ctrls, Sizer}
%% 		Config	=	list of tuple
%% 		Panel	=	wxWindow()
%% 		Ctrls	=	list of ??
%% 		Sizer	=	Id of sizer where objects are belongs
%%
%% @doc
%%
%% @end
%% --------------------------------------------------------------------
create(Config) when is_list(Config) ->
	Parent = proplists:get_value(parent, Config),
	Label = proplists:get_value(label, Config),
	
	Panel = wxPanel:new(Parent),
	
	SeizerOptions = [{border,4}, {flag, ?wxEXPAND}],
	
	%%error_logger:info_report(["create_subwindow/3", {parent, Parent}, {boxLabel, BoxLabel}, {funs, Funs}, {module, ?MODULE}, {line, ?LINE}]),
	
	MainSizer = wxBoxSizer:new(?wxVERTICAL),
	
	%% Find number of sizer do we need. It is depends of that we need to put
	%% extra buttons or not.
	{SizerList, ButtonList} = case proplists:get_value(button_list, Config) of
							   undefined ->
								   %% Only one sizer is needed
								   {[wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, Label}])], []};
							   
							   L ->
								   %% We need 3 sizers
								   
								   S1_T = wxStaticBoxSizer:new(?wxVERTICAL, Panel, [{label, Label}]),
								   S2_T = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel, [{label, ""}]),
								   S3_T = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel, [{label, ""}]),
										   
								   {[S1_T, S2_T, S3_T], L}
						   end,
	%% Create an entry. The Text of this will filter the list of ListBoxExt
	FilterEntry = wxTextCtrl:new(Panel, ?WX_FILTERBOX_ENTRY_ID, [{value, ""}, 
																 {style, ?wxDEFAULT}]),
	wxTextCtrl:connect(FilterEntry, command_text_updated),
	wxTextCtrl:setToolTip(FilterEntry, "Enter the text for filtering listbox"),
	
	wxSizer:add(hd(SizerList), FilterEntry, SeizerOptions),
	wxSizer:addSpacer(hd(SizerList), 10),
	
	%% Create a checkbox for "Select All" items in listbox
	SelectAllCheckBox = wxCheckBox:new(Panel, ?WX_FILTERBOX_CHECKBOX_ID, "Select all", []),
	wxCheckBox:connect(SelectAllCheckBox, command_checkbox_clicked),
	wxSizer:add(hd(SizerList), SelectAllCheckBox, SeizerOptions),
	wxSizer:addSpacer(hd(SizerList), 10),
	
	%% Create a wxListBox that uses multiple selection
	ListBox = wxListBox:new(Panel, ?WX_FILTERBOX_LISTBOX_ID, [{size, {200,100}},
															  {choices, []},
															  {style, ?wxLB_MULTIPLE bor ?wxLB_ALWAYS_SB}]),
	wxListBox:setToolTip(FilterEntry, "Type any text for filtering"),
	wxListBox:connect(ListBox, command_listbox_selected),
	
	case erlang:length(SizerList) of
		1 ->
			%% There are no extra buttons
			wxSizer:add(hd(SizerList), ListBox, SeizerOptions),
			wxSizer:add(MainSizer, hd(SizerList), SeizerOptions);
		_->	
			%% These are the new sizers
			[S1,S2,S3] = SizerList,
			%% Add some extra buttons
			[begin
				 ButtonObj = wxButton:new(Panel, ButtonId, [{label, ButtonLabel}]),
				 wxSizer:add(S3, ButtonObj, [{border, 5}, {flag, ?wxALL}]),
				 wxButton:connect(ButtonObj, command_button_clicked)
			 end || {ButtonId, ButtonLabel} <- ButtonList],
			
			wxSizer:add(S2, ListBox),
			wxSizer:add(S2, S3),
			wxSizer:add(S1, S2),
			
			wxSizer:add(MainSizer, S1, SeizerOptions)
	end,
	
	wxPanel:setSizer(Panel, MainSizer),
	
	ObjList = [{get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.filter_entry_id), FilterEntry}, 
			   {get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.select_all_check_box_id), SelectAllCheckBox},
			   {get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.listbox_id), ListBox},
			   {get_record_field_name(?LISTBOXEXT_OBJECT_NAMES, #rFILTERBOX_OBJECT_NAMES.main_sizer_id), MainSizer}],
	
	error_logger:info_report(["create/1", {parent, Parent}, {boxLabel, Label}, {config, Config}, {self_pid, self()}, {module, ?MODULE}, {line, ?LINE}]),
	
	{Panel, ObjList}.

%% --------------------------------------------------------------------
%% Give the list of items on ListBox
%% Input:
%%		ListBoxId	:	wxWindow()
%% Output:
%%		Items		:	list
%% --------------------------------------------------------------------
do_ListBoxCtrl_GetItems(ListBoxId) ->
	%% Get number of items first
	case wxListBox:getCount(ListBoxId) of
		0 ->
			[];
		Cnt when is_integer(Cnt) ->
			%% Read the items one-by-one
			[wxListBox:getString(ListBoxId, I) || I <- lists:seq(0, Cnt-1)];
		_->	%% Something wrong
			[]
	end.

%% --------------------------------------------------------------------
%% Append items to listbox
%% Input:
%%		ListBoxId	:	wxWindow()
%%		Items		:	list
%% Output:
%%		ok
%% --------------------------------------------------------------------
do_filterBoxCtrl_AppendItems(ListBoxId, Items) ->
	[begin 
		 wxListBox:append(ListBoxId, Item)
		 %%Id = wxListBox:findString(ListBoxId, Item),
		 %%io:format("Item: ~p, Id: ~p, Text: ~p~n",[Item, Id, wxListBox:getString(ListBoxId, Id)])
	 end || Item <- Items],
	ok.

%% --------------------------------------------------------------------
%% Delete all items to listbox
%% Input:
%%		ListBoxId	:	wxWindow()
%% Output:
%%		ok
%% --------------------------------------------------------------------
do_filterBoxCtrl_Clear(ListBoxId) ->
	wxListBox:clear(ListBoxId),
	ok.

%% --------------------------------------------------------------------
%% Get selected items in listbox
%% Input:
%%		ListBoxId	:	wxWindow()
%% Output:
%%		{ok, Items}
%% --------------------------------------------------------------------
do_filterBoxCtrl_GetSelectedItems(ListBoxId) ->
	%%{ok,{2,[0,3]}}
	SelectedItems = case wxListBox:getSelections(ListBoxId) of
						{_Cnt, SelectedItemsId} ->
							[begin
								 wxListBox:getString(ListBoxId, Id)
							 end || Id <- SelectedItemsId];
						_->	[]
					end,
	
	{ok, lists:sort(SelectedItems)}.

%% --------------------------------------------------------------------
%% Delete all selected items
%% Input:
%%		ListBoxId	:	wxWindow()
%% Output:
%%		ok
%% --------------------------------------------------------------------
do_filterBoxCtrl_DeleteSelectedItems(ListBoxId) ->
	%% WARNING:
	%%  wxListBox:delete/2 deletes ONE item, but after that
	%% the Id of Items changed, thus deletion in a loop see below
	%% does not working :-(
	%% 	case wxListBox:getSelections(ListBoxId) of
	%% 		{_Cnt, SelectedItemsId} ->
	%% 			[begin
	%% 				 io:format("Id: ~p, text: ~p~n", [Id, wxListBox:getString(ListBoxId, Id)]),
	%% 				 wxListBox:delete(ListBoxId, Id)
	%% 			 end || Id <- SelectedItemsId];
	%% 		_->	[]
	%% 	end,

	%% Right solution
	do_filterBoxCtrl_DeleteSelectedItems_loop(ListBoxId).

do_filterBoxCtrl_DeleteSelectedItems_loop(ListBoxId) ->
	case wxListBox:getSelections(ListBoxId) of
		{0, _} ->
			%% No selected items
			ok;
		{_Cnt, [Id|_T]} ->
			wxListBox:delete(ListBoxId, Id),
			do_filterBoxCtrl_DeleteSelectedItems_loop(ListBoxId)
	end.

%% --------------------------------------------------------------------
%% Select all items in listbox
%% Input:
%%		ListBoxId	:	wxWindow()
%% Output:
%%		ok
%% --------------------------------------------------------------------
do_ListBoxCtrl_SelectAllItems(ListBoxId) ->
	%% Select Imtes one-by-one
	[begin
		 wxListBox:select(ListBoxId, I)
	 end || I <- lists:seq(0, wxListBox:getCount(ListBoxId))],
	ok.

%% --------------------------------------------------------------------
%% Unselect all items in listbox
%% Input:
%%		ListBoxId	:	wxWindow()
%% Output:
%%		ok
%% --------------------------------------------------------------------
do_ListBoxCtrl_UnselectAllItems(ListBoxId) ->
	%% Get all Items first
	Items = do_ListBoxCtrl_GetItems(ListBoxId),
	
	%% Delete all items
	wxListBox:clear(ListBoxId),
	
	%% Add items one-by-one
	[begin
		 wxListBox:append(ListBoxId, Item)
	 end || Item <- Items],
	ok.

%% --------------------------------------------------------------------
%% Filter items in listbox
%% Input:
%%		ListBoxId	:	wxWindow()
%%		SubString	:	string, filter the items by this
%%		DefaultItems:	default list of items, use this when SubString = "" or "*"
%% Output:
%%		ok
%% --------------------------------------------------------------------
do_ListBoxCtrl_FilterItems(ListBoxId, SubString, DefaultItems) ->
	FilteredItems = case DefaultItems of
						"" ->
							DefaultItems;
						
						"*" ->
							DefaultItems;
						
						_->	%% Do filter
							filter_list(DefaultItems, SubString)
					end,
	%%error_logger:info_report(["do_ListBoxCtrl_FilterItems", {subString, SubString}, {defaultItems, DefaultItems}, {filteredItems, FilteredItems}]),
	do_filterBoxCtrl_Clear(ListBoxId),
	do_filterBoxCtrl_AppendItems(ListBoxId, FilteredItems),
	ok.

%% --------------------------------------------------------------------
%% Filter the listbox item by substring
%% Input :
%%		List		:	list of items
%%		SubString	:	string
%% Output:
%%		NewList		:	list of filtered items
%% --------------------------------------------------------------------
filter_list(List, SubString) ->
	do_filter_list(List, SubString, []).

do_filter_list([], _SubString, Result)->
	lists:sort(Result);
do_filter_list([Head | Tail], SubString, Result)->
	%% Get the first x char from the Head name. If it is equal with the typed have to put to the 
	%% Result.
	%% Get the 1st char of the SubString. * means any strings...
	case catch string:substr(SubString, 1, 1) of
		{'EXIT',_}	->
			%% Error occured...
			do_filter_list([], SubString, [Head | Tail]);
		"*"	->
			%% The 1st char is *
			%% A is the *, B is the typed string after *
			{_A,B} = lists:split(1,SubString),
			case B of
				[]	->
					%% Only * had been typed...returns with all modules
					do_filter_list([], SubString, [Head | Tail]);
				_->	
					%% * and other char had been typed...
					%% If Head contains B substring have to insert this in the Result
					case string:str(Head,B) of
						0 ->
							%% No Head is not contains B(substring)
							do_filter_list(Tail,SubString,Result);
						_->	
							%% Yes, Head is contains B(substring)
							do_filter_list(Tail, SubString, [Head | Result])
					end
			end;
		
		_->
			Str = string:substr(Head, 1, length(SubString)),
			case Str == SubString of
				true ->
					%% It is same with it...
					do_filter_list(Tail, SubString, [Head | Result]);
				false ->
					%% It is not same with it...
					do_filter_list(Tail, SubString, Result)
			end
	end.

%% --------------------------------------------------------------------
%% Check Server accessibility
%% Input:
%%		Server	:	pid() | atom()
%% Output:
%%		boolean()
%% --------------------------------------------------------------------
check_server_accessibility(Server) when is_pid(Server) ->
	erlang:is_process_alive(Server);
check_server_accessibility(Server) when is_atom(Server) ->
	case whereis(Server) of
		P when is_pid(P) ->
			true;
		_->	false
	end.

%% --------------------------------------------------------------------
%% Give the name of field in the record.
%% Input:
%%		RecordFields	:	list of fields in the record
%%		FieldId			:	integer, position of field in the record
%% Input:
%%		FieldName		:	atom, the name of the field
%% --------------------------------------------------------------------
get_record_field_name(RecordFields, FieldId) ->
	lists:nth(FieldId-1, RecordFields).

