-ifndef(tracer_hrl).
-define(tracer_hrl, true).

%% --------------------------------------------------------------------
%% Defines
%% --------------------------------------------------------------------
-define(TOOL_VERSION, "0.0.3").

-define(WX_OBJECT_CALL_TO, 5000).
-define(MAIN_TITLE, "ETracer").

-define(BTN_ID_SETUP, 100).
%%-define(BTN_ID_START, 102).
%%-define(BTN_ID_STOP, 103).
-define(BTN_ID_START_STOP, 102).
-define(BTN_ID_CLEAR, 104).
-define(BTN_ID_NEWTRACE, 105).
-define(BTN_ID_SAVE, 106).

-define(ENTRY_ID_NEWTRACE, 						201).
-define(ENTRY_ID_ERLANG_NODE, 					202).
-define(ENTRY_ID_ERLANG_NODE_COOKIE, 			203).
-define(ENTRY_ID_SAVE_LOG_ON_FLY, 				204).
-define(UNDETERMINISTIC_GAUGE_ID, 				205).
-define(FILTERBOX_CHECKBOX_ID_SAVE_LOG_ON_FLY, 	206).

-define(WX_ETRACER_MENU_ID_SAVE_SETTINGS, 8000).

-define(MAIN_WINDOW_HIGHT, 650).
-define(MAIN_WINDOW_WIDTH, 1000).
-define(MAIN_WINDOW_SIZE, {?MAIN_WINDOW_WIDTH,?MAIN_WINDOW_HIGHT}).

-define(DEFAULT_ERLANG_NODE, node()).
-define(DEFAULT_ERLANG_NODE_COOKIE, dmxc).

-define(GEN_SERVER_CALL_TO, 5000).

-define(DEFAULT_TRACER_PORT,4711).
-define(DEFAULT_MSG_QUEUE_SIZE,50000).

%% --------------------------------------------------------------------
%% Record of Wx Obj Id names to be used in Tracer Tab
%% --------------------------------------------------------------------
-record(rTRACER_TAB_OBJECT_NAMES, {
								   parent_panel_id,								  
								   setup_tracemeasure_btn_id,
								   start_stop_trace_btn_id,
								   save_trace_btn_id,
								   clear_trace_btn_id,
								   erlang_node_entry_id,
								   erlang_node_cookie_entry_id,
								   trace_log_window_id,
								   save_log_on_fly_checkbox_id,
								   save_log_on_fly_entry_id,
								   gauge_id,
								   
								   trace_flag_call_checkbox_id,
								   trace_flag_send_checkbox_id,
								   trace_flag_receive_checkbox_id,
								   trace_flag_proc_checkbox_id,
								   
								   trace_matchspecification_flag_message_id,
								   trace_matchspecification_flag_return_trace_id,
								   trace_matchspecification_flag_process_dump_id
								  }).
-define(TRACER_TAB_OBJECT_NAMES, record_info(fields, rTRACER_TAB_OBJECT_NAMES)).

%% --------------------------------------------------------------------
%% Record for Trace Flags
%% --------------------------------------------------------------------
-record(rTraceFlags, {
					  message = m,
					  send = s,
					  'receive' = r,
					  call = c,
					  procs = p
					 }).
-define(TRACE_FLAGS_NAME, record_info(fields, rTraceFlags)).
-define(DEFAULT_TRACE_FLAGS, [?GET_RECORD_FIELD_NAME(?TRACE_FLAGS_NAME, #rTraceFlags.call)]).

%% --------------------------------------------------------------------
%% Record for Trace Flags
%% --------------------------------------------------------------------
-record(rTraceMatchSpecificationFlags, {
					  message,
					  return_trace,
					  process_dump}).
-define(TRACE_MATCH_SPECIFICATION_FLAGS_NAME, record_info(fields, rTraceMatchSpecificationFlags)).
-define(DEFAULT_MATCH_SPECIFICATION_FLAGS, [?GET_RECORD_FIELD_NAME(?TRACE_MATCH_SPECIFICATION_FLAGS_NAME, #rTraceMatchSpecificationFlags.return_trace)]).

%% --------------------------------------------------------------------
%% Give the name of field in the record.
%% --------------------------------------------------------------------
-define(GET_RECORD_FIELD_NAME(RecordFields, FieldId), 
	begin
		lists:nth(FieldId-1, RecordFields)
	end).

%% --------------------------------------------------------------------
%%              Define MNESIA table list
%%---------------------------------------------------------------------
-define(ETRACER_CONFIG_TABLE, etracer_config_table).
-record(rETracerConfig,{
				  name,						%% string, name of the TAB
				  vsn_0 = {val,vsn_0},		%% version handling, see documentation in mnesia_transform.erl
				  erlang_node,				%% atom
				  erlang_node_cookie,		%% atom
				  trace_pattern = [],		%% list of tuple, example: [{M,F,A}, {M,F,A}, ...]
				  trace_flags = ?DEFAULT_TRACE_FLAGS,							%% list of atom, example: [message, send, receive, call]
				  trace_match_spec_flags = ?DEFAULT_MATCH_SPECIFICATION_FLAGS,	%% list of atom, example: [message, processdump, return_trace]
					
				  object_list = [],			%% the list of wxWidget Objs are puted on the TAB.
											%% Basically these are temporal data, but for handling all data belongs to the TAB in one hand, I choose this solution.
											%% Must flush this when ETracer restart and update with new values when TAB created. 
				  trace_status = off,		%% atom, status of Trace. It can be: on | off
				  gauge_tref = undefined	%% Timer ref
				 }).
-define(ETRACER_CONFIG_TABLE_ATTRIBUTES,
    [?ETRACER_CONFIG_TABLE,
    [{attributes, record_info(fields,rETracerConfig)},
     {record_name,rETracerConfig},
     {disc_copies,[node()]},
     {type,set}]]).

-define(mnesia_table_list,[?ETRACER_CONFIG_TABLE_ATTRIBUTES]).

-define(MNESIA_TRANSFORM_MODULES,
        [
         etracer
        ]).

%%-----------------------------------------------------------------------------------------
%% Create the table if it's not created yet.
%% Populate it with {{Recordname,Fieldname},Index} tuples.
%% Then notify the Boss that we're done.
%% This from ETHTZP, for solving some load problme at fetching record position of field in record.
%%-----------------------------------------------------------------------------------------
-define(RECORD_INFO_TABLE, record_info_table).
-define(RECORD_FIELDS_TABLE, record_fields_table).
-define(RECORD_LIST,
        [
        ?FI(rETracerConfig),
		?FI(rTraceMatchSpecificationFlags),
		?FI(rTraceFlags),
		?FI(rTRACER_TAB_OBJECT_NAMES)
        ]).


%% --------------------------------------------------------------------
%% Labels
%% --------------------------------------------------------------------
-define(START_TRACE_BTN_LABEL, "Start Trace").
-define(STOP_TRACE_BTN_LABEL, "Stop Trace").

%%----- End of external record definition -------------------------------------------------


-endif.