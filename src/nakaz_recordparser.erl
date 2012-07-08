-module(nakaz_recordparser).
-export([parse_transform/2]).

-include("nakaz_internal.hrl").

-define(BUILTIN_TYPES, [any,binary,integer,pos_integer,neg_integer,non_neg_integer,
			range,number,string,nonempty_string,module,node,timeout,
			none,byte,char,nil,list,nonempty_list,tuple,float,
			record,boolean,atom]).

parse_transform(Forms, _Options) ->
    Func = generate_specs_getter(Forms, [config]),
    FExport = generate_export(),
    %% We should insert export before any function definitions
    Forms2 = parse_trans:do_insert_forms(above, [FExport, Func], Forms, []),
%    io:format("Forms2 ~p~n", [Forms2]),		
    Forms2.

generate_specs_getter(Forms, ReqRecs) ->
    {Specs, Deps} = extract_records_specs(Forms),
    io:format("Specs ~p~nDeps: ~p~n", [Specs, Deps]),
    ReqRecs1 = find_required_recs(ReqRecs, Deps),
    io:format("Req Recs: ~p ~n", [ReqRecs1]),
    ok = check_records(Specs, ReqRecs1),

    Func = erl_syntax:function(erl_syntax:atom(?NAKAZ_MAGIC_FUN),
                               [erl_syntax:clause(
                                  [],
                                  none,
                                  [erl_syntax:abstract({ok, Specs})])]),
    erl_syntax:revert(Func).

find_required_recs(Reqs, AllDeps) ->
    ReqNested = [[Req, proplists:get_value(Req, AllDeps,[])]
		 || Req <- Reqs],
    ordsets:from_list(lists:flatten(ReqNested)).

check_records(_Specs, _Reqired) ->
    ok.

%% FIXME: better export attribute generation
generate_export() ->
    {attribute, 0, export, [{?NAKAZ_MAGIC_FUN, 0}]}.

extract_records_specs(Forms) ->
    Module = parse_trans:get_module(Forms),
    lists:foldl(fun (F,Acc) -> handle_type(F,Acc,Module) end,
                {[], []},
                Forms).

handle_type(Form, Acc, Module) ->
    case erl_syntax_lib:analyze_form(Form) of
        {attribute, {type, {type, Type}}} ->
            handle_record(Type, Acc, Module);
        _ ->
            Acc
    end.

%% Handle only records types
handle_record({{record, Name}, Fields, _Args},
              {AccRecs, AccRefs},
              Module) ->
    {Refs, F} = try [handle_field(Field, Module) || Field <- Fields] of
                    Fld -> {lists:foldl(fun accum_record_refs/2,
                                        ordsets:new(),
                                        Fld),
                            Fld}
    catch
        throw:{unsupported_field,
               Form,
               Module} -> {unsupported,
                           element(2,Form), %FIXME: Form always has 3 elements?
                           Module}
    end,
    io:format("REFS FOR ~p : ~p~n", [Name, Refs]),
    %% Update ordset only if record is one of already referenced
    AccRecs2 = [{Name, F} | AccRecs],
    AccRefs2 = [{Name, Refs} | AccRefs],
    {AccRecs2, AccRefs2};
handle_record(_, Acc, _) ->
    Acc.

accum_record_refs({_Name, {_M, record, [Arg]}, _}, Acc) ->
    ordsets:add_element(Arg, Acc);
accum_record_refs(_, Acc) ->
    Acc.

handle_field({typed_record_field,
              {record_field,_,{atom,_,Name}}, Type}, Module) ->
    Field = handle_field_type(Type, Module),
    {Name, Field, undefined};
%% Handle special case with default value
handle_field({typed_record_field,
              {record_field,_,{atom,_,Name}, Default}, Type}, Module) ->
    Field = handle_value_param(Type, Module),
    Def = handle_value_param(Default, Module),
    {Name, Field, Def};
handle_field(Other, Module) ->
    throw({unsupported_field, Other, Module}).

%%FIXME: Only allow typed fields
%%FIXME: Maybe there are different orders of 'undefined' atom
%%       and other term in union
handle_field_type({type,_,union,[{atom,_,undefined},
                                 Value]}, Module) ->
    handle_value_param(Value, Module);
handle_field_type(Other, Module) ->
    throw({unsupported_field, Other, Module}).

handle_value_param({remote_type, _, [{atom,_,Module},
                                      {atom,_,Type},
                                      Args]}, _Module) ->
    {Module,
     Type,
     [handle_value_param(Arg, Module) || Arg <- Args]};
handle_value_param({type,_,record,[]}=Form, Module) ->
    %% We do not support generic record type
    throw({unsupported_field, Form, Module});
handle_value_param({type, _, Type, Args}, Module) when is_list(Args) ->
    {get_module_for_type(Type,Module),
     Type,
     [handle_value_param(Arg, Module) || Arg <- Args]};
handle_value_param({type,_, Type, Arg}, Module) ->
    %% Handle special case when type arguments is not list
    {get_module_for_type(Type, Module),
     Type,
     [Arg]};
handle_value_param({atom,_, Atom}, _) ->
    Atom;
handle_value_param({integer,_,Integer}, _) ->
    Integer;
handle_value_param({op,_, '-', {integer,_,Integer}}, _) ->
    %% Unary minus. Special case. Again.
    -Integer;
handle_value_param({float,_,Float}, _) ->
    Float;
handle_value_param({boolean,_,Boolean}, _) ->
    Boolean;
handle_value_param({tuple,_,Values}, Module) ->
    list_to_tuple([handle_value_param(V, Module) || V <- Values]);
handle_value_param({_,LineNo,_}, Module) ->
    throw({unsupported_field, LineNo, Module}).

get_module_for_type(Type, DefaultModule) ->
    case lists:member(Type, ?BUILTIN_TYPES) of
	true ->
	    undefined;
	false -> DefaultModule
    end.
    
