-module(gateway_log_ffi).
-export([
    configure/0, format/2, info/2, set_request_id/1, clear_request_id/0
]).

-define(OWN_KEYS, [<<"time">>, <<"level">>, <<"msg">>, <<"request_id">>]).

configure() ->
    ok = logger:update_handler_config(default, #{formatter => {?MODULE, #{}}}),
    nil.

info(Msg, Fields) ->
    logger:info([{msg, Msg} | [{binary_to_atom(K), V} || {K, V} <- Fields]]),
    nil.

set_request_id(Id) ->
    logger:update_process_metadata(#{request_id => Id}),
    nil.

clear_request_id() ->
    case logger:get_process_metadata() of
        #{request_id := _} = Meta ->
            logger:set_process_metadata(maps:remove(request_id, Meta));
        _ ->
            ok
    end,
    nil.

format(#{level := Level, msg := Msg, meta := Meta}, _Config) ->
    try
        {Text, Fields} = message(Msg, Meta),
        Pairs =
            time(Meta)
            ++ [{<<"level">>, atom_to_binary(Level)}, {<<"msg">>, Text}]
            ++ request_id(Meta)
            ++ [{K, V} || {K, V} <- Fields, not lists:member(K, ?OWN_KEYS)],
        [object(Pairs), $\n]
    catch
        _:_ ->
            [object([{<<"level">>, atom_to_binary(Level)},
                     {<<"msg">>, inspect(Msg)}]), $\n]
    end.

time(#{time := Time}) ->
    Formatted = calendar:system_time_to_rfc3339(
        Time, [{unit, microsecond}, {offset, "Z"}]
    ),
    [{<<"time">>, list_to_binary(Formatted)}];
time(_) ->
    [].

request_id(#{request_id := Id}) -> [{<<"request_id">>, value(Id)}];
request_id(_) -> [].

%% logger attaches format_otp_report/1 to every report by default. It flattens
%% the fields into text, so only a report's own callback is used.
message({report, Report}, Meta) ->
    Default = fun logger:format_otp_report/1,
    case maps:get(report_cb, Meta, Default) of
        Default ->
            report(Report);
        Callback when is_function(Callback, 1) ->
            {Format, Args} = Callback(Report),
            {text(io_lib:format(Format, Args)), []};
        Callback when is_function(Callback, 2) ->
            {text(Callback(Report, #{})), []}
    end;
message({string, String}, _Meta) ->
    {text(String), []};
message({Format, Args}, _Meta) ->
    {text(io_lib:format(Format, Args)), []}.

report(Report) when is_map(Report) ->
    report(maps:to_list(Report));
report(Pairs) ->
    Fields = [{key(K), value(V)} || {K, V} <- Pairs],
    case lists:keytake(<<"msg">>, 1, Fields) of
        {value, {_, Text}, Rest} when is_binary(Text) -> {Text, Rest};
        {value, {_, Text}, Rest} -> {inspect(Text), Rest};
        false -> {<<>>, Fields}
    end.

key(K) when is_atom(K) -> atom_to_binary(K);
key(K) when is_binary(K) -> K;
key(K) -> inspect(K).

value(V) when is_binary(V) ->
    case unicode:characters_to_binary(V) of
        Utf8 when is_binary(Utf8) -> Utf8;
        _ -> inspect(V)
    end;
value(V) when is_integer(V); is_float(V); is_boolean(V) -> V;
value(V) when is_atom(V) -> atom_to_binary(V);
value(V) -> inspect(V).

text(Chardata) ->
    case unicode:characters_to_binary(Chardata) of
        Utf8 when is_binary(Utf8) -> Utf8;
        _ -> inspect(Chardata)
    end.

inspect(Term) ->
    'gleam@string':inspect(Term).

object(Pairs) ->
    Members = [[json:encode(K), $:, json:encode(V)] || {K, V} <- Pairs],
    [${, lists:join($,, Members), $}].
