-include_lib("nakaz.hrl").
%% FIXME(Dmitry): COMMENTARIES FOR TYPES!

-type record_() :: tuple(). %% Dialyzer doesn't know about type "record"

-type raw_position() :: {Line   :: non_neg_integer(),
                         Column :: non_neg_integer()}.
-type raw_term()   :: {atom(), raw_field()}
                    | binary().
-type raw_field()  :: {raw_term(), raw_position()}.
-type raw_config() :: [raw_field()].

-type typed_term()  :: term().
-type typed_field() :: {atom(), typed_term()}.
-type typed_config() :: [typed_field()].

-type typer_error() :: {missing, Name :: atom()}
                     | {invalid,
                        Name  :: atom(),
                        Type  :: atom(),
                        Value :: binary()}.

-type composer_error() :: {unknown_anchor, binary()}
                        | {duplicate_anchor, binary()}
                        | {duplicate_key, atom()}.

-type reload_type() :: sync | async.

-type ret_novalue() :: ok
                     | {error, Reason :: binary()}.

-type ret_value(T) :: {ok, T}
                    | {error, Reason :: binary()}.

-type record_field_spec() :: {FieldName :: atom(),
			      Typespec :: nakaz_typespec(),
			      Default :: any()}.

-type record_spec() :: {Name :: atom(),
                        [record_field_spec()]}.

-type record_specs() :: [record_spec()].

-define(NAKAZ_MAGIC_FUN, nakaz_magic_fun_that_should_be_autogenerated).

-type proplist() :: [{any(), any()}].
-type proplist(K, V) :: [{K, V}].

-type typical_file_errors() :: enoent
                             | eaccess
                             | eisdir
                             | enomem
                             | system_limit.

-type untypical_readfile_errors() :: badarg
                                   | terminated.

-type config_structure_error() :: {malformed, [{section, atom()} |
                                               {app, atom()}]}.

-type read_config_file_errors() ::
        typical_file_errors()
      | binary()
      | composer_error()
      | config_structure_error().

-type read_config_errors() ::
        read_config_file_errors()
      | {cant_execute_magic_fun, atom()} %%%%!!!!
      | {missing, {app, atom()}}
      | {missing, {section, atom()}}
      | typer_error().
