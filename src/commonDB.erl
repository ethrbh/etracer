%% $Id: commonDB.erl 935 2012-02-06 13:40:00Z elsziva $

%%-----------------------------------------------------------------------------------------
%% Common database (DB) functions are located here
%%-----------------------------------------------------------------------------------------

-module(commonDB).

-behaviour(gen_server).

%%-----------------------------------------------------------------------------------------
%% Include files
%%-----------------------------------------------------------------------------------------
-include("../include/commonDB.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%-----------------------------------------------------------------------------------------
%% External exports
%%-----------------------------------------------------------------------------------------
-export([start/1, stop/0]).
-export([fieldIndexes/2]).
-export([get_record_element_pos/2, get_record_element_name/2]).
-export([get_record_info/1]).
-export([make_match_specification/4, make_match_specification_advanced/2]).

         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %%          ETS HANDLING
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([createETSTable/1, createETSTable/2, createETSTable/3]).
-export([get_table_key_pos/1]).
-export([save_table_to_file/2, load_table_from_file/1, copy_table/2, is_table/1]).
-export([update_table_record/2, get_table_record/2, get_table_record_field/3, delete_table_record/2]).
-export([init_ets_tables/1, waiting_for_ets_tables/1]).


         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %%          MNESIA HANDLING
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-export([
    init_mnesia_tables/2,           %% Init MNESIA tables
    set_mnesia_db/1,                %% Set path of MNESIA db
    create_mnesia_schema/0,         %% Create default mnesia schema of xxGW
    create_mnesia_table/2,          %% Create mnesia table
    create_all_mnesia_table/1,      %% Create all pre-defined mnesia table. Definiton is in xGWCommon.hrl
                                    %% under MNESIA section
    update_mnesia_table_record/2,   %% Update the record in the MNESIA table
    delete_mnesia_table_record/2,   %% Delete record from MNESIA table
    
    waiting_for_mnesia_tables/2,    %% loading MNESIA tables, and waits until it finished
    waiting_for_mnesia_tables/3     %% loading MNESIA tables, and waits until it finished
    ]).

%%-----------------------------------------------------------------------------------------
%% gen_server callbacks
%%-----------------------------------------------------------------------------------------
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%-----------------------------------------------------------------------------------------
%%                          DEFINES
%%-----------------------------------------------------------------------------------------
-define(SERVER, ?MODULE).

%%-----------------------------------------------------------------------------------------
%% Internal record definition
%%-----------------------------------------------------------------------------------------
-record(rLoopData, {}).

%%=========================================================================================
%% External functions
%%=========================================================================================
%%-----------------------------------------------------------------------------------------
%% Start commonDB server
%% Input:
%%      RECORD_LIST -   list of ?FI(RECORD), eq: [?FI(R1), ?FI(R2), ...]
%% Output:
%%      {ok, Pid} | {nok, Reason}
%%-----------------------------------------------------------------------------------------
start(RECORD_LIST) ->
    stop(),
    timer:sleep(100),
    gen_server:start({local, ?SERVER}, ?MODULE, [RECORD_LIST], []).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%%Stop application
%%-----------------------------------------------------------------------------------------
stop()->
    case catch gen_server:call(?SERVER,stop,3000) of
        {'EXIT',{noproc,_}} -> {nok,not_running};
        {'EXIT',{timeout,_}} -> {nok,gen_server_call_timeout};
        Reply -> Reply
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Generate the {{RecName, Field}, N} and {{RecName, N}, Field} tuples in a list.
%%-----------------------------------------------------------------------------------------
fieldIndexes(RecName, Fields) ->
    fieldIndexes(RecName, Fields, 1, []).
fieldIndexes(_, [], _, Acc) ->
    lists:flatten(Acc);
fieldIndexes(RecName, [Field|T], N, Acc) ->
    fieldIndexes(RecName, T, N+1, [[{{RecName, Field}, N}, {{RecName, N}, Field}] | Acc]).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Get position of Elelement in the record. The first matched position will be return. If there is no
%% element in the List the return value is 0.
%% Find the index of Element in the given Record. 
%% Returns: 1..N if the record field is found; 0 if not found.
%% Input:   Element     -   atom
%%          RecordName  -   atom, name of the field in the record
%% Output:  Pos         -   integer
%%-----------------------------------------------------------------------------------------
get_record_element_pos(Element, RecordName) when is_atom(Element) ->
    case catch ets:lookup(?R2CTAB, {RecordName, Element}) of
        [{{RecordName, Element}, Num}] when is_integer(Num) ->
            Num;
        [] ->
            0 %% Now we REALLY return 0 :)
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Get name of Elelement in the record. The first matched position will be return. If there is no
%% element in the List the return value is 0.
%% Find the index of Element in the given Record. 
%% Returns: 1..N if the record field is found; 0 if not found.
%% Input:   Pos         -   integer
%%          RecordName  -   atom, name of the field in the record
%% Output:  Element     -   atom
%%-----------------------------------------------------------------------------------------
get_record_element_name(Pos, RecordName) when is_integer(Pos) ->
    case catch ets:lookup(?R2CTAB, {RecordName, Pos}) of
        [{{RecordName, Pos}, Element}] when is_atom(Element) ->
            Element;
        [] ->
            0 %% Now we REALLY return 0 :)
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Give the list of fields of record in relatime.
%% Input:
%%      RecName -   atom, name of the record
%% Output:
%%      Fields  -   list
%%-----------------------------------------------------------------------------------------
get_record_info(RecName)->
    case catch ets:lookup(?R2CTAB, RecName) of
        Fields when is_list(Fields)->
            Fields;
        _-> []
    end.
%%----- End of function -------------------------------------------------------------------

         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %%          ETS/MNESIA MATCH SPECIFICATION
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%-----------------------------------------------------------------------------------------
%% @doc
%% Give the list of matched records in the table.
%% Input:
%%      Record          -       record
%%      Field           -       integer | atom, name of position of the Field in the record
%%      OP              -       atom, operator: eq: '==' | '/=' | '>' | '<'
%%      Value           -       any, to what should  be matched of Value of the Field
%% Output:
%%      Result          -       list of records that matched with the request
%% @end
%%-----------------------------------------------------------------------------------------
make_match_specification(Record, FieldName, OP, Value) when is_atom(FieldName)->
        make_match_specification(Record, get_record_element_pos(FieldName, Record), OP, Value);

make_match_specification(_Record, FieldPos, OP, Value) when is_integer(FieldPos) , OP == '==' ->
        ets:fun2ms(fun(Input) when element(FieldPos, Input) == Value -> Input end);
make_match_specification(_Record, FieldPos, OP, Value) when is_integer(FieldPos) , OP == '/=' ->
        ets:fun2ms(fun(Input) when element(FieldPos, Input) /= Value -> Input end);
make_match_specification(_Record, FieldPos, OP, Value) when is_integer(FieldPos) , OP == '>' ->
        ets:fun2ms(fun(Input) when element(FieldPos, Input) > Value -> Input end);
make_match_specification(_Record, FieldPos, OP, Value) when is_integer(FieldPos) , OP == '<' ->
        ets:fun2ms(fun(Input) when element(FieldPos, Input) < Value -> Input end);
make_match_specification(_Record, _FieldPos, OP, _Value) ->
        {nok, lists:concat(["Invalid operator: ", OP])}.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Build the whole match_specifiaction for ets:select/2
%% Input:
%%      Rec     -   atom, name of the record
%%      Filters -   list of tuple of filters: eq: [{field, operator, match_value}, ...]
%% Output:
%%      [{H,G,R}]-  for ets:select
%%-----------------------------------------------------------------------------------------
make_match_specification_advanced(Rec, Filters)->
    make_match_specification_advanced_loop(Rec, Filters, []).

make_match_specification_advanced_loop(_Rec, [], MatchSpec)->
    MatchSpec;
make_match_specification_advanced_loop(Rec, [{Field, Op, Value} | T], [])->
    [{H,G,R}] = make_match_specification(Rec, Field, Op, Value),
    make_match_specification_advanced_loop(Rec, T, [{H,G,R}]);
make_match_specification_advanced_loop(Rec, [{Field, Op, Value} | T], [{H,G,R}])->
    [{_H,G2,_R}] = make_match_specification(Rec, Field, Op, Value),
    make_match_specification_advanced_loop(Rec, T, [{H,G++G2,R}]).
%%----- End of function -------------------------------------------------------------------

         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %%          ETS HANDLING
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         
%%-----------------------------------------------------------------------------------------
%% This function will be create a new ETS table.
%%-----------------------------------------------------------------------------------------
createETSTable(TableName) ->
    createETSTable(TableName, [ordered_set,public,named_table]).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be create a new ETS table.
%% Input:   TableName   -   atom
%%          Pos         -   integer
%% Output: table is created
%%-----------------------------------------------------------------------------------------
createETSTable(TableName, Pos) when is_integer(Pos) ->
    createETSTable(TableName, [ordered_set,public,named_table,{keypos,Pos}]);
createETSTable(TableName, ParamList) when is_list(ParamList) ->
    createETSTable(TableName, ParamList, 0).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be create a new ETS table.
%% Input:   TableName   -   atom
%%          Type        -   atom, set | ordered_set | bag | duplicate_bag  
%%          Pos         -   integer
%% Output: table is created
%%-----------------------------------------------------------------------------------------
createETSTable(TableName, Type, Pos) when is_atom(Type) ->
    createETSTable(TableName, [Type,public,named_table], Pos);
createETSTable(TableName, ParamList, Pos) when is_list(ParamList) ->
    case ets:info(TableName) of
        undefined ->
            case Pos of
                0-> ets:new(TableName, ParamList);
                _-> ets:new(TableName, ParamList++[{keypos,Pos}])
            end;
        _-> ets:delete(TableName),
            case Pos of
                0-> ets:new(TableName, ParamList);
                _-> ets:new(TableName, ParamList++[{keypos,Pos}])
            end
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Give the position if Key of the Table
%% Input:   Table   -   atom
%% Output:  Pos     -   integer
%%-----------------------------------------------------------------------------------------
get_table_key_pos(Table) when is_list(Table)->
    get_table_key_pos(list_to_atom(Table));
get_table_key_pos(Table) when is_atom(Table)->
    Info = case ets:info(Table) of
        I when is_list(I)->
            I;
        I when is_tuple(I)->
            tuple_to_list(I)
    end,
    case my_proplists:find_var(keypos, Info) of
        undefined ->
            1;
        P-> P
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Save table in the db dir
%% Input:   TableName   -   atom, name of the table what have to save
%%          FileName    -   string, path and file name
%% Output:  -
%%-----------------------------------------------------------------------------------------
save_table_to_file(TableName,FileName)->
    ets:tab2file(TableName,FileName).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Load table from the db dir. The table name os stored in the file and no need set here.
%% Input:   FileName    -   string, path and file name
%% Output:  {ok, Table} | {error,Reason}
%%-----------------------------------------------------------------------------------------
load_table_from_file(FileName)->
    case catch ets:file2tab(FileName) of
        {'EXIT',R1} ->  {error,lists:concat([R1," ",FileName])};
        {ok,Table}  ->  {ok, Table};
        {error,R2}  ->  {error,lists:concat([R2," ",FileName])}
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Copy all entries of the table in an other table
%% Input:   FromTable   -   atom, name of the source table
%%          ToTable     -   atom, name of the destination table
%% Output:  ok | {nok,Reason}
%%-----------------------------------------------------------------------------------------
copy_table(FromTable,ToTable) when is_list(FromTable)->
    copy_table(list_to_atom(FromTable),ToTable);
copy_table(FromTable,ToTable) when is_list(ToTable)->
    copy_table(FromTable,list_to_atom(ToTable));
copy_table(FromTable,ToTable)->
    %% Take all entries from the FromTable
    %% get the KeyPositio of the source table
    KeyPos = get_table_key_pos(FromTable),
    From = ets:tab2list(FromTable),
    
    %% Check the ToTable is exists or not
    case is_table(ToTable) of
        true ->
            %% Table is already exists...must be destroy and create agin
            catch ets:delete(ToTable),
            createETSTable(ToTable, KeyPos);
        false ->
            %% Table is not exists yet...
            createETSTable(ToTable, KeyPos)
    end,
    
    %% Copy the FromTable to ToTable
    copy_table_loop(ToTable,From).

copy_table_loop(_ToTable,[])->
    ok;
copy_table_loop(ToTable,[Head | Tail])->
    ets:insert(ToTable,Head),
    copy_table_loop(ToTable,Tail).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Check the table is exists or not
%% Input:   TableName   -   atom
%% Output:  boolean
%%-----------------------------------------------------------------------------------------
is_table(TableName) when is_list(TableName)->
    is_table(list_to_atom(TableName));
is_table(TableName)->
    case ets:info(TableName) of
        {'EXIT',_} -> false;
        undefined  -> false;
        _          -> true
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be update the record of the table
%% Input:   Table   -   atom, name of the table
%%          ConnRec -   Rercord of the connection
%% Output:  ok | {nok,Reason}
%%-----------------------------------------------------------------------------------------
update_table_record(Table,Record)->
    case ets:insert(Table,Record) of
        true ->
            ok;
        Else ->
            {nok,Else}
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be give the record in the table
%% Input:   Table   -   atom, name of the table
%%          Key     -   key of the table
%% Output:  [] | Record | {nok,Reason}
%%-----------------------------------------------------------------------------------------
get_table_record(Table,Key)->
    ets:lookup(Table,Key).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will return a field of a record in the table
%% Input:   Table   -   atom, name of the table
%%          Key     -   key of the table
%%          Position -  field position in the record
%% Output:  [] | Record | {nok,Reason}
%%-----------------------------------------------------------------------------------------
get_table_record_field(Table, Key, Pos)->
    case ets:lookup_element(Table, Key, Pos) of
        {'EXIT',_} ->
            [];
        Else ->
            Else
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% This function will be delete the record from the table
%% Input:   Table   -   atom, name of the table
%%          Key     -   key of the table
%% Output:  ok | {nok,Reason}
%%-----------------------------------------------------------------------------------------
delete_table_record(Table,Key)->
    case catch ets:delete(Table,Key) of
        {'EXIT',R}->
            {nok,R};
        _-> ok
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Init ETS tables
%% Input:
%%      TableList   -   list, list of tuple of name and key_pos of ETS
%% Output:
%%      ok | {nok, Reason}
%%-----------------------------------------------------------------------------------------
init_ets_tables(TableList) when is_list(TableList)->
    [begin
        createETSTable(T, KeyPos)
     end || {T, KeyPos} <- TableList],
     
    STARTED_ETS_TABLES = waiting_for_ets_tables(TableList),
    
    error_logger:info_report(["All ETS tables are started.",
                              {tables, STARTED_ETS_TABLES}]),
    ok.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Waits until all ETS tables are created
%% Input:
%%      ETS_Table_List  -   list of atom
%% Output:
%%      ETS_Table_List  -   list of atom
%%-----------------------------------------------------------------------------------------
waiting_for_ets_tables(ETS_Table_List) when is_list(ETS_Table_List) ->
    waiting_for_ets_tables_loop(ETS_Table_List, []).

waiting_for_ets_tables_loop([], Tables)->
    Tables;
waiting_for_ets_tables_loop([H|T], Tables) when is_tuple(H)->
    {Table, _KeyPos} = H,
    waiting_for_ets_tables_loop([Table | T], Tables);
waiting_for_ets_tables_loop([H|T], Tables) when is_list(H)->
    [Table, _Attr] = H,
    waiting_for_ets_tables_loop([Table | T], Tables);
waiting_for_ets_tables_loop([Table|T], Tables) when is_atom(Table)->
    case catch ets:info(Table, size) of
        I when is_integer(I)->
            waiting_for_ets_tables_loop(T, lists:append([Tables, [Table]]));
        _-> waiting_for_ets_tables_loop(lists:append([T, [Table]]), Tables)
    end.
%%----- End of function -------------------------------------------------------------------


         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %%          MNESIA HANDLING
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%-----------------------------------------------------------------------------------------
%% Init MNESIA tables
%% Input:
%%      DBDir   -   string, path of MNESIA DB
%%      Tables  -   list of attributes of all MNESIA tables
%% Output:
%%      ok | {nok, Reason}
%%-----------------------------------------------------------------------------------------
%init_mnesia_tables(DBDir, Tables)->
%    %% Stop MNESIA if it's running...
%    catch mnesia:stop(),
%    
%    %% Create Database folder if it doesn't exists
%    file:make_dir(DBDir),
%    
%    %% Set MNESIA database path
%    set_mnesia_db(DBDir),
%    
%    %% Create MNESIA schema
%    create_mnesia_schema(),
%    
%    %% Start MNESIA application
%    mnesia:start(),
%    
%    %% Need to be check all table are visible
%    create_all_mnesia_table(Tables),
%    
%    STARTED_MNESIA_TABLES = waiting_for_mnesia_tables(Tables, 10000, 20),
%    
%    error_logger:info_report(["All MNESIA tables are started.",
%                              {tables, STARTED_MNESIA_TABLES}]),
%    ok.

init_mnesia_tables(DBDir, Tables) ->
    %io:format("@@@ init_mnesia_tables~n", []),
    do_init_mnesia_tables(mnesia_stop, DBDir, Tables).

do_init_mnesia_tables(mnesia_stop, DBDir, Tables) ->
    %% Stop MNESIA if it's running...
    catch mnesia:stop(),
    do_init_mnesia_tables(make_dir, DBDir, Tables);

do_init_mnesia_tables(make_dir, DBDir, Tables) ->
    %% Create Database folder if it doesn't exists
    case file:make_dir(DBDir) of
        {error, Reason} ->
            case Reason of
                eexist ->
                    %io:format("@@@ init_mnesia_tables: make_dir, eexist OK~n", []),
                    do_init_mnesia_tables(set_mnesia_db, DBDir, Tables);
                _Other ->
                    error_logger:error_report(["init_mnesia_tables", {stage, make_dir}, {reason, Reason}, {dbDir, DBDir}]), 
                    {nok, Reason}
            end;
        ok ->
            %directory created successfully
            %io:format("@@@ init_mnesia_tables: make_dir OK~n", []),
            do_init_mnesia_tables(set_mnesia_db, DBDir, Tables)
    end;

do_init_mnesia_tables(set_mnesia_db, DBDir, Tables) ->
    %% Set MNESIA database path
    case set_mnesia_db(DBDir) of
        {nok, Reason} ->
            error_logger:error_report(["init_mnesia_tables", {stage, set_mnesia_db}, {reason, Reason}, {dbDir, DBDir}]), 
            {nok, Reason};
        _ ->
            %successfull
            io:format("@@@ init_mnesia_tables: set_mnesia_db OK~n", []),
            do_init_mnesia_tables(create_mnesia_schema, DBDir, Tables)
    end;

do_init_mnesia_tables(create_mnesia_schema, DBDir, Tables) ->
    case create_mnesia_schema() of
        {error, Reason} ->
            case Reason of
                {_,{already_exists,_}} ->
                    %io:format("@@@ init_mnesia_tables: create_mnesia_schema, already_exists OK~n", []),
                    do_init_mnesia_tables(start_mnesia, DBDir, Tables);
                _Other ->
                    error_logger:error_report(["init_mnesia_tables", {stage, create_mnesia_schema}, {reason, Reason}]), 
                    {nok, Reason}
            end;
        ok ->
            io:format("@@@ init_mnesia_tables: create_mnesia_schema OK~n", []),
            do_init_mnesia_tables(start_mnesia, DBDir, Tables)
    end;

do_init_mnesia_tables(start_mnesia, DBDir, Tables) ->
    case mnesia:start() of
        {error, Reason} ->
            error_logger:error_report(["init_mnesia_tables", {stage, start_mnesia}, {reason, Reason}]), 
            {nok, Reason};
        ok ->
            %io:format("@@@ init_mnesia_tables: start_mnesia OK~n", []),
            do_init_mnesia_tables(create_tables, DBDir, Tables)
    end;

do_init_mnesia_tables(create_tables, _DBDir, Tables) ->
    %% Need to be check all table are visible
    _TablesResults = create_all_mnesia_table(Tables),
    %error_logger:info_report(["@@@ init_mnesia_tables", {stage, create_tables}, {tables, TablesResults}]),
    
    STARTED_MNESIA_TABLES = waiting_for_mnesia_tables(Tables, 10000, 20),
    
    error_logger:info_report(["All MNESIA tables are started.",
                              {tables, STARTED_MNESIA_TABLES}]),
    ok.



%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Set path of MNESIA database
%% Input:   Path    -   string
%% Output:  ok | {nok,Reason}
%%-----------------------------------------------------------------------------------------
set_mnesia_db(Path) when is_atom(Path)->
    set_mnesia_db(atom_to_list(Path));
set_mnesia_db(Path) when is_list(Path)->
    case catch application:set_env(mnesia, dir, Path) of
        {'EXIT',_} -> {nok,"error occured at settin up MNESIA DB"};
        Other      -> Other
    end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Create default mnesia schema of xxGW
%% Input: - 
%% Output: ok | {error,Reason}
%%-----------------------------------------------------------------------------------------
create_mnesia_schema()->
    mnesia:create_schema([node()]).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Create mnesia table
%% Input:   TableName       -   atom
%%          AttributeList   -   list of attributes, for more information see MNESIA description
%% Output:  ok | {error,Reason}
%%-----------------------------------------------------------------------------------------
create_mnesia_table(TableName,AttributeList)->
    mnesia:create_table(TableName,AttributeList).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Create all pre-defined mnesia table. Definiton is in xGWCommon.hrl under MNESIA section.
%% Input:
%%      TableList   -   list of MNESIA tables
%% Output:
%%      0
%%-----------------------------------------------------------------------------------------
create_all_mnesia_table(TableList)->
    create_all_mnesia_table_loop(TableList,[]).
    
create_all_mnesia_table_loop([],Result)->
    Result;
create_all_mnesia_table_loop([TableInfo | Tail],Result)->
    [TableName,AttributeList] = TableInfo,
    R = mnesia:create_table(TableName,AttributeList),
    create_all_mnesia_table_loop(Tail,Result++[R]).
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Update the record in the MNESIA table
%% Input:   TableName   -   atom
%%          Record      -   record of table | list of record
%% Output:  ok | {nok,Reason}
%%-----------------------------------------------------------------------------------------
update_mnesia_table_record(TableName,Record) when is_list(TableName)->
    update_mnesia_table_record(list_to_atom(TableName),Record);
update_mnesia_table_record(TableName,RecordList) when is_atom(TableName), is_list(RecordList) ->
    Fun = fun()->
            [mnesia:write(TableName,Record,write) || Record <- RecordList]
          end,
    case mnesia:sync_transaction(Fun) of
		{atomic, ok} ->
			ok;
		Reason ->
			{nok, Reason}
	end;
update_mnesia_table_record(TableName,Record) when is_atom(TableName)->
    Fun = fun()->
            mnesia:write(TableName,Record,write)
          end,
    case mnesia:sync_transaction(Fun) of
		{atomic, ok} ->
			ok;
		Reason ->
			{nok, Reason}
	end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Delete record from MNESIA table
%% Input:   TableName   -   atom
%%          Key         -   key of the table record
%% Output:  ok | {nok,Reason}
%%-----------------------------------------------------------------------------------------
delete_mnesia_table_record(TableName,Key) when is_list(TableName)->
    delete_mnesia_table_record(list_to_atom(TableName),Key);
delete_mnesia_table_record(TableName,Key) when is_atom(TableName)->
    Fun = fun()->
            mnesia:delete(TableName,Key,write)
          end,
    case mnesia:sync_transaction(Fun) of
		{atomic, ok} ->
			ok;
		Reason ->
			{nok, Reason}
	end.
%%----- End of function -------------------------------------------------------------------

%%-----------------------------------------------------------------------------------------
%% Waits until all MNESIA tables are created
%% Input:
%%      Tables  -   list of table definitions, see xxAXECommon/mnesia_table_list
%%      Timeout -   integer, timeout in miliseconds (for one try)
%%      Retries -   integer, retries
%% Output:
%%      Tables  -   list of atom
%%-----------------------------------------------------------------------------------------
waiting_for_mnesia_tables(Tables,Timeout) ->
    waiting_for_mnesia_tables(Tables,Timeout,0).
    
waiting_for_mnesia_tables(Tables,Timeout,Retries) when is_list(Tables), is_integer(Timeout), is_integer(Retries) ->
    Fun = fun({Tab,_KeyPos}) -> Tab;
             ([Tab,_Attr]) -> Tab;
             (Tab) when is_atom(Tab) -> Tab
          end,
    Tabs = lists:map(Fun,Tables),

    waiting_for_mnesia_tables_loop(Tabs,Timeout,Retries).

waiting_for_mnesia_tables_loop(Tabs,Timeout,Retries) ->

    %% crash if not successful
    case mnesia:wait_for_tables(Tabs,Timeout) of
        ok ->
            Tabs;
        {timeout,BadTabList} ->
            case Retries of
                0 ->
                    error_logger:error_report(["Mnesia table start timeout no more retries, crashing myself intentionally.",
                                               {timeout,Timeout},
                                               {not_started_tables,BadTabList}]),
                    %% crash intentionally
                    ok = Retries;
                _ ->
                    error_logger:info_report(["Mnesia table start timeout, retrying...",
                                              {timeout,Timeout},
                                              {not_started_tables,BadTabList},
                                              {remaining_retries,Retries}]),
                    waiting_for_mnesia_tables_loop(Tabs,Timeout,Retries - 1)
            end;
        Other ->
            error_logger:error_report(["Mnesia table start problem, crashing myself intentionally.",
                                      {timeout,Timeout},
                                      {reason,Other}]),
            %% crash intentionally
            ok = Other
    end.
%%----- End of function -------------------------------------------------------------------

%%=========================================================================================
%% Server functions
%%=========================================================================================

%%-----------------------------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, LoopData}          |
%%          {ok, LoopData, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%%-----------------------------------------------------------------------------------------
init([RECORD_LIST]) ->
    %% Create ETS table
    ets:new(?R2CTAB, [ordered_set, public, named_table]),
    
    %% Insert data into ETS
    InsertFun = fun({{RecName, RecFields}, RecordList}) -> 
        ets:insert(?R2CTAB, RecordList),
        ets:insert(?R2CTAB, {RecName, RecFields})
    end,
    lists:foreach(InsertFun, RECORD_LIST),
    
    {ok, #rLoopData{}}.

%%-----------------------------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, LoopData}          |
%%          {reply, Reply, LoopData, Timeout} |
%%          {noreply, LoopData}               |
%%          {noreply, LoopData, Timeout}      |
%%          {stop, Reason, Reply, LoopData}   | (terminate/2 is called)
%%          {stop, Reason, LoopData}            (terminate/2 is called)
%%-----------------------------------------------------------------------------------------
handle_call(stop, _From, LoopData) ->
    {stop, normal, ok, LoopData};
    
handle_call(_Request, _From, LoopData) ->
    Reply = ok,
    {reply, Reply, LoopData}.

%%-----------------------------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, LoopData}          |
%%          {noreply, LoopData, Timeout} |
%%          {stop, Reason, LoopData}            (terminate/2 is called)
%%-----------------------------------------------------------------------------------------
handle_cast(_Msg, LoopData) ->
    {noreply, LoopData}.

%%-----------------------------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, LoopData}          |
%%          {noreply, LoopData, Timeout} |
%%          {stop, Reason, LoopData}            (terminate/2 is called)
%%-----------------------------------------------------------------------------------------
handle_info(_Info, LoopData) ->
    {noreply, LoopData}.

%%-----------------------------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%%-----------------------------------------------------------------------------------------
terminate(_Reason, _LoopData) ->
    ok.

%%-----------------------------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process rLoopData when code is changed
%% Returns: {ok, NewState}
%%-----------------------------------------------------------------------------------------
code_change(_OldVsn, LoopData, _Extra) ->
    {ok, LoopData}.

%%-----------------------------------------------------------------------------------------
%%% Internal functions
%%----------------------------------------------------------------------------------------- 
