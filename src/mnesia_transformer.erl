%%%=============================================================================
%%% MNESIA table transform framework
%%% 
%%% Documentation:
%%% --------------
%%% 
%%% This transform framework requires conventions in records that are subject to transform.
%%% 
%%% Record name should be RecName_vX in the new code. Don't worry example will follow :-)
%%% The 3rd element name of the record should be vsn_X and value should be {val_vsnX} where
%%% X is an integer >= 1
%%% 
%%% Why 3rd. element?
%%% -----------------
%%% First element is record name, and second is the key (in mnesia the key should be the second)
%%% 
%%% What happens if the record already exists in the application but without this convention?
%%% -----------------------------------------------------------------------------------------
%%% It is handled as legacy record _v0. Legacy records should be handled in a special way in 
%%% transform_mnesia_table callback function.
%%%
%%% Example history of a record:
%%% ----------------------------
%%% First there was -record{myRec,{key,myField,myProp,....}}
%%% 
%%% Now we want to introduce a new field myAttr, so:
%%% 
%%% o rename myRec to myRec_v0: -record{myRec_v0,{key,myField,myProp,....}}
%%% o create the new record with the new field and add the mandatory vsn field (with value):
%%%   -record{myRec,{key,vsn_1 = {val,vsn_1},myField,myAttr,myProp,....}}
%%%   Note that in the erlang code the record names don't have to be modified!
%%%   It is intentional: the myRec record always have the current record.
%%% 
%%% Later we want to add a new field again (myName):
%%% o rename myRec to myRec_v1: -record{myRec_v1,{key,vsn_1 = {val,vsn_1},myField,myAttr,myProp,....}}
%%% o create the new record with the new field and step vsn field (with value):
%%%   -record{myRec,{key,vsn_2 = {val,vsn_2},myField,myAttr,myProp,myName,....}}
%%% 
%%% And so on.
%%% 
%%% If you are about to introduce a new record then you should add the vsn field from the beginning
%%% to get rid of the lagacy-record handling hack.
%%%
%%% When the application starts and it has been started mnesia then it should call:
%%% -------------------------------------------------------------------------------
%%% 
%%% mnesia_transformer:check_mnesia_transform(TransformDbMod,Mnesia_Transform_Modules).
%%% 
%%%   TransformDbMod: The module that the user can call to do the transform.
%%%       This function will call the generic transform functions in
%%%       this module. In this function this parameter is used only to print 
%%%       usage info. See Callbacks section below for additional info.
%%%                   
%%%   Mnesia_Transform_Modules: list of atoms, module names                
%%%       The real record transform can be done in several modules but not  
%%%        necessary to have more than one.
%%% 
%%%   !!! This function exits intentionally if transform is needed!
%%%   This way you can be sure that application will not continue with 
%%%   non-transformed database.
%%%   All necessary info is printed to the user how to proceed.
%%% 
%%% The TransportDbMod should implement a functions called transform_database/0,1
%%% This function calls   
%%%    mnesia_transformer:transform_database(TransformDbMod,Mnesia_Transform_Modules).
%%% For more info see Callbacks section below.
%%% 
%%% 
%%% 
%%% ===================================
%%% Callbacks that must be implemented:
%%% ===================================
%%%
%%% -----------------------------------
%%% TransformDbMod:transform_database/0
%%% TransformDbMod:transform_database/1
%%% -----------------------------------
%%%    It is not a callback but discussed here. The user will call this function to do the transform.
%%% 
%%%    this have to look like:
%%%    transform_database() ->
%%%       mnesia_transformer:transform_database(?MODULE,[dummy],not_sure).
%%% 
%%%    transform_database(Mode) ->
%%%        %% The macros have to be set by you according to your implementation
%%%        mnesia_transformer:transform_database(?TRANSFORM_DB_MOD,?MNESIA_TRANSFORM_MODULES,Mode).
%%% 
%%% --------------------------------------------------------
%%% Mnesia_Transform_Mod:transform_mnesia_table_get_tables/0
%%% --------------------------------------------------------
%%%    This should return List of TransformInfo tuples:
%%%       {TabName,{NewRecName,NewRecFields}}
%%%      TabName: atom, table name that may need transformation
%%%      NewRecName: atom, new record name in the table
%%%      NewRecFields: New record fields (use record_info(fields,NewRecName) here)
%%%      Example: {?gwcTable, {rGWC, record_info(fields, rGWC)}}
%%% 
%%% --------------------------------------------------------
%%% Mnesia_Transform_Mod:transform_mnesia_table({What,Rec}).
%%% --------------------------------------------------------
%%%    Here comes the tricky part. It is better if you see an already implemented
%%%    example i.e. xGWDatabaseHandling:transform_mnesia_table/1
%%% 
%%%    How it works?
%%%    -------------
%%%    This transform framework first calls this function with
%%%    What = rec_attributes, Rec = old record in table that may be transformed
%%%    
%%%    Function should return with:
%%%       {ok,needed} if transform is needed and possible
%%%       {ok,not_needed} if transform is not needed
%%%       {nok,Reason} if transform is needed but not possible or not supported
%%% 
%%%    In the second round and in case transform is needed this function is called with
%%%    What = rec, Rec = old record in table that needs to be transformed
%%% 
%%%    Function should return with:
%%%       {ok,NewRec} where NewRec is the new record
%%%       {nok,Reason} in case of any problem
%%%    Don't be afraid to use constructs that may crash in case of unexpected data, etc.
%%%    This function call is catched by the framework and transform error is printed.
%%% 
%%%=============================================================================
-module(mnesia_transformer).

%%%=============================================================================
%%% Include files
%%%=============================================================================

%%%=============================================================================
%%% Defines
%%%=============================================================================

%%%=============================================================================
%%% Exports
%%%=============================================================================
-export([
         check_mnesia_transform/2,
         transform_database/3
        ]).

%%%=============================================================================
%%% External functions
%%%=============================================================================

%%%=============================================================================
%%% Check if transform is needed and provide user with info how to proceed.
%%%
%%% Input: see documentation above
%%%
%%% Output: ok (if transform is not needed) | exit erlang (if transform is needed)
%%%
%%%=============================================================================
check_mnesia_transform(TransformDbMod,Mnesia_Transform_Modules) ->
    io:format("~n********************************************************************************~n"),
    io:format("~n  M n e s i a   d a t a b a s e   t r a n s f o r m a t i o n~n",[]),
    io:format("~n********************************************************************************~n"),
    
    case check_transform_needed(Mnesia_Transform_Modules) of
        {ok,not_needed} -> ok;
        {ok,needed} -> 
            transform_database_warning(),

            io:format("   Now I will exit immediatly. Start the tool with the '-test' switch ~n",[]),
            io:format("   then run this command:~n~n",[]),
            io:format("   ~p:transform_database().~n~n",[TransformDbMod]),
            io:format("   Bye.~n",[]),
            erlang:halt(),
            nok;
        {nok,_Reason} ->
            io:format("~n   Now I will exit immediatly, please contact tool support or start with~n"),
            io:format("   a new empty databas (delete the old).~n~n"),
            io:format("   Bye.~n",[]),
            erlang:halt(),
            nok
    end.

%%%=============================================================================
%%% Execute database transform
%%%
%%% Input: 
%%%    TransformDbMod,Mnesia_Transform_Modules: see documentation above
%%%    Mode: sure | real | not_sure | Other
%%%         dry: just dry run, no database is written
%%%         sure: dry run and if it is successful: real run
%%%         not_sure: called when user instructions should be printed.
%%%         Other: not expected mode: usage info is printed.
%%%
%%% Output: ok (in case of successful dry mode run) 
%%%         | nok (in case of unsuccessful dry mode run or when unexpected Mode is given)
%%%         | exit erlang (in case Mode = sure)
%%%
%%%=============================================================================
transform_database(TransformDbMod,Mnesia_Transform_Modules,Mode) ->
    case Mode of 
        sure ->
            case transform_all(Mnesia_Transform_Modules,real) of
                ok ->
                    io:format("~n   Now I will exit immediatly. Start the tool with the usual parameters.~n",[]),
                    io:format("   Bye.~n",[]),
                    erlang:halt(),
                    ok;
                nok ->
                    io:format("~n   Now I will exit immediatly, please contact tool support or start with~n"),
                    io:format("   a new empty databas (delete the old).~n~n"),
                    io:format("   Bye.~n",[]),
                    erlang:halt(),
                    nok
            end;
        dry ->
            case transform_all(Mnesia_Transform_Modules,dry) of
                ok ->
                    io:format("   Dry run was successful, you can continue with real run (if transform is needed):~n"),
                    io:format("      ~p:transform_database(sure).~n~n",[TransformDbMod]),
                    ok;
                nok ->
                    io:format("   *** Dry run failed, please contact tool support or start with empty database~n"),
                    nok
            end;
                    
        not_sure -> io:format("~n"),
            transform_database_warning(),
            io:format("   Database transfor has a 'dry run' feature: the transform is attempted but ~n"),
            io:format("   database is not written. The purpose is to pre-check if transform would be successful.~n"),
            io:format("   To run transform in 'dry mode' run this command:~n~n"),
            io:format("      ~p:transform_database(dry).~n~n",[TransformDbMod]),
            io:format("   If it reports success then you can continue with 'real' transform:~n~n"),
            io:format("      ~p:transform_database(sure).~n~n",[TransformDbMod]),
            ok;
        _ -> 
            io:format("~n*** Unexpected mode '~p'",[Mode]),
            io:format("~n*** Run ~p:transform_database() to get further instructions~n",[TransformDbMod]),
            nok
    end.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

transform_database_warning() ->    
    io:format("   Transform is an automatic process and should run without any problem.~n"),
    io:format("   Measures are taken to avoid database structure inconsistency even if~n"),
    io:format("   one of the table transformation fails.~n"),
    io:format("   On the other hand it is not impossible that something goes wrong so~n",[]),
    io:format("   you should decide if you would like to backup the database before the~n",[]),
    io:format("   transformation starts. The worst thing that may happen is that you~n",[]),
    io:format("   have to start with an empty database.~n~n",[]),
    ok.

check_transform_needed(Mnesia_Transform_Modules) ->
    io:format("================================================================~n"),
    io:format("Checking if transform is needed.~n~n"),

    case do_check_transform_needed(Mnesia_Transform_Modules) of
        {nok,Reason} ->
            io:format("~n================================================================~n"),
            io:format("*** Transform is needed but not possible, see printouts above.~n"),
            {nok,Reason};
        {ok,not_needed} ->
            io:format("~n================================================================~n"),
            io:format("Transform not needed.~n~n"),
            {ok,not_needed};
        {ok,needed,_Db} ->
            io:format("~n================================================================~n"),
            io:format("### Transform is needed.~n~n"),
            {ok,needed}
    end.

transform_all(Mnesia_Transform_Modules,Mode) ->
    io:format("================================================================~n"),
    io:format("Transform mnesia tables start. First checking if transform is needed.~n~n"),

    case do_check_transform_needed(Mnesia_Transform_Modules) of
        {nok,_Reason} ->
            io:format("~n================================================================~n"),
            io:format("*** Transform not possible, see printouts above.~n~n"),
            nok;
        {ok,not_needed} ->
            io:format("~n================================================================~n"),
            io:format("Transform not needed.~n~n"),
            ok;
        {ok,needed,Db} ->
            io:format("----------------------------------------------------------------~n"),
            io:format("Transform needed, transform test with dry run.~n~n"),
            case do_transform(dry,Db) of
                ok -> 
                    case Mode of
                        dry ->
                            io:format("~n================================================================~n"),
                            io:format("Dry run was successful~n~n"),
                            ok;
                        real ->
                            io:format("----------------------------------------------------------------~n"),
                            io:format("Dry run was successful, proceeding to do real transform.~n~n"),
                                case do_transform(real,Db) of
                                    ok ->
                                        io:format("~n================================================================~n"),
                                        io:format("Transform was successful~n~n"),
                                        ok;
                                    {nok,_} -> 
                                        io:format("~n================================================================~n"),
                                        io:format("*** Transform failed, see printouts above.~n~n"),
                                        nok
                                end
                    end;
                {nok,_} -> 
                    io:format("~n================================================================~n"),
                    io:format("*** Transform dry run failed, see printouts above.~n"),
                    nok
            end
            
    end.

%%%-------------------------------------------------------------
%%% Check if the mnesia transform is needed on modules
%%% Output:
%%%   {ok,needed,TransformDb} | {ok,not_needed} | {nok,Reason}
%%%     -TransformDb: Database of modules/tables on which transformation is needed
%%%      [{Mod1,[{TabM11,Attrx},{TabM12,Recy}, ...]}, ... {Modx,[{TabMx1,Recz},{TabMx2,Recw}, ...}]
%%%      Recxyzw: The new record
%%%
%%%-------------------------------------------------------------
do_check_transform_needed(Mnesia_Transform_Modules) ->

    Fun2 = fun({Mod,Tab,RecInf},Acc) ->
                   io:format("   -~p: ",[Tab]),
                   Res = case check_if_transform_needed_table(Mod,Tab) of
                             {nok,Reason} ->
                                 io:format("~p~n",[{nok,Reason}]),
                                 {nok,Reason};
                             {ok,needed} ->
                                 io:format("==> transform needed~n"),
                                 {ok,needed,{Tab,RecInf}};
                             {ok,not_needed} ->
                                 io:format("transform not needed~n"),
                                 {ok,not_needed}
                         end,
                   case {Acc,Res} of
                       {{nok,_},_} -> Acc;
                       {{ok,needed,_},{ok,not_needed}} -> Acc;
                       {{ok,needed,Db},{ok,needed,T1}} -> {ok,needed,Db ++ [T1]};
                       {{ok,needed,_},{nok,_}} -> Res;
                       {{ok,not_needed},{ok,needed,T1}} -> {ok,needed,[T1]};
                       {{ok,not_needed},_} -> Res
                   end
           end,

    Fun = fun(Mod,Acc) ->
                  io:format("~n~p: ",[Mod]),
                  %% get tables that is taken care of by the module
                  Res = case catch Mod:transform_mnesia_table_get_tables() of
                            {'EXIT',Reason} ->
                                io:format("~p~n",[{nok,{get_table_problem,Mod,Reason}}]),
                                {nok,{get_table_problem,Mod,Reason}};
                            Tables when is_list(Tables)->
                                Tabsx = [Tab || {Tab,_} <- Tables],
                                io:format("~p~n",[Tabsx]),
                                MTabRecInf = [{Mod,Tab,RecInf} || {Tab,RecInf} <- Tables],
                                lists:foldl(Fun2,{ok,not_needed},MTabRecInf);
                            Other ->
                                io:format("~p~n",[{nok,{get_table_problem_other,Mod,Other}}]),
                                {nok,{get_table_problem_other,Mod,Other}}
                        end,
                  case {Acc,Res} of
                      {{nok,_},_} -> Acc;
                      {{ok,needed,_},{ok,not_needed}} -> Acc;
                      {{ok,needed,Db},{ok,needed,Tabs1}} -> {ok,needed,Db ++ [{Mod,Tabs1}]};
                      {{ok,needed,_},{nok,_}} -> Res;
                      {{ok,not_needed},{ok,needed,Tabs1}} -> {ok,needed,[{Mod,Tabs1}]};
                      {{ok,not_needed},_} -> Res
                  end
          end,
    lists:foldl(Fun,{ok,not_needed},Mnesia_Transform_Modules).
    
            
%%%-------------------------------------------------------------
%%% Check if the mnesia transform is needed on table and if
%%% it is possible.
%%% Input:
%%%   -Mod: module that performs the transform
%%%   -Tab: table to be transformed
%%%
%%% Output:
%%%   {ok,needed} | {ok,not_needed} | {nok,Reason}
%%%
%%%
%%%-------------------------------------------------------------
check_if_transform_needed_table(Module,Tab) ->
    Fun = fun() ->
                  RecN = mnesia:table_info(Tab,record_name),
                  Attrs = mnesia:table_info(Tab,attributes),
                  {RecN,Attrs}
          end,
    case catch Fun() of
        {'EXIT',Reason} ->
            {nok,{error1,Reason}};
        {RecN,Attrs} ->
            %% construct record
            Fun2 = fun(A,Acc) ->
                           erlang:append_element(Acc,A)
                   end,
            OldRec = lists:foldl(Fun2,{RecN},Attrs),
            case catch Module:transform_mnesia_table({rec_attributes,OldRec}) of
                {'EXIT',Reason} ->
                    {nok,{error2,Reason}};
                {nok,Reason} ->
                    {nok,Reason};
                {ok,not_needed} ->
                    %% transformation not needed
                    {ok,not_needed};
                {ok,needed} ->
                    %% transformation needed
                    {ok,needed};
                Unexpected ->
                    {nok,{unexpected_reply_from_transform_func,Unexpected}}
            end
    end.

%%%-------------------------------------------------------------
%%% Transform all mnesia tables
%%% Input:
%%%   -Mode: dry | real
%%%   -Db: transform database see do_check_transform_needed/0
%%% Output:
%%%   ok | {nok,Reason}
%%%
%%%
%%%-------------------------------------------------------------
do_transform(Mode,Db) ->
    FunTabs = fun({Mod,{Tab,RecInf}},Acc) ->
                      io:format("   ~p: ",[Tab]),
                       Res = case Mode of
                                 dry ->
                                     %% just call the transform function
                                     FunDryEts = fun(OldRec,AccE) ->
                                                         ResE = case catch Mod:transform_mnesia_table({rec,OldRec}) of
                                                                    {'EXIT',Reason} ->
                                                                        {nok,{error,Mod,Tab,Reason}};
                                                                    {nok,Reason} ->
                                                                        {nok,Reason};
                                                                    {ok,not_needed} ->
                                                                        ok;
                                                                    {ok,_NewRec} ->
                                                                        ok
                                                                end,
                                                         case {AccE,ResE} of
                                                             {{nok,_},_} -> AccE;
                                                             {ok,_} -> ResE
                                                         end
                                                 end,
                                     ets:foldl(FunDryEts,ok,Tab);
                                 real ->
                                     FunWrap = fun(OldRec) ->
                                                       {ok,NewRec} = Mod:transform_mnesia_table({rec,OldRec}),
                                                       NewRec
                                               end,
                                     {NewRecName,NewAttrs} = RecInf,
                                     case mnesia:transform_table(Tab,FunWrap,NewAttrs,NewRecName) of
                                         {atomic,ok} ->
                                             ok;
                                         Other ->
                                             {nok,Other}
                                     end
                             end,
                      io:format(" ~p~n",[Res]),
                      case {Acc,Res} of
                          {{nok,_},_} -> Acc;
                          {ok,_} -> Res
                      end
              end,

    FunMods = fun({Mod,TabRecs},Acc) ->
                      io:format("~n~p:~n",[Mod]),
                      MTabRecs = [{Mod,TabRec} || TabRec <- TabRecs],
                      Res = lists:foldl(FunTabs,ok,MTabRecs),
                      case {Acc,Res} of
                          {{nok,_},_} -> Acc;
                          {ok,_} -> Res
                      end
           end,
    lists:foldl(FunMods,ok,Db).

