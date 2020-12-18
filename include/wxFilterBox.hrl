-ifndef(wxFilterBox_hrl).
-define(wxFilterBox_hrl, true).

%% --------------------------------------------------------------------
%% Defines
%% --------------------------------------------------------------------
-define(WX_FILTERBOX_LISTBOX_ID, 1).
-define(WX_FILTERBOX_CHECKBOX_ID, 2).
-define(WX_FILTERBOX_ENTRY_ID, 3).


-define(WX_FILTERBOX_GENSERVER_CALL_TO, 5000).

%% --------------------------------------------------------------------
%% Record of Wx Obj Id names to be used in Tracer Tab
%% --------------------------------------------------------------------
-record(rFILTERBOX_OBJECT_NAMES, {
								   filter_entry_id,
								   select_all_check_box_id,
								   listbox_id,
								   main_sizer_id
								  }).
-define(LISTBOXEXT_OBJECT_NAMES, record_info(fields, rFILTERBOX_OBJECT_NAMES)).

%% Button list to be placed beside the ListBox
-record(rFILTERBOX_BUTTONS, {
							 add = {1, "Add item"},
							 delete = {2, "Delete item"}}).

%% Action definitions to be use
-record(rFILTERBOX_ACTIONS,{
							 command_listbox_selected}).
-define(FILTERBOX_ACTIONS_NAMES, record_info(fields, rFILTERBOX_ACTIONS)).

-endif.