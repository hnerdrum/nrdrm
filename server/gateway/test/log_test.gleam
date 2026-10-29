import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string
import gleam/string_tree.{type StringTree}
import gleeunit/should

@external(erlang, "gateway_log_ffi", "format")
fn ffi_format(event: Dynamic, config: Dynamic) -> StringTree

@external(erlang, "erlang", "binary_to_atom")
fn atom(name: String) -> Dynamic

fn map(entries: List(#(String, Dynamic))) -> Dynamic {
  dynamic.properties(list.map(entries, fn(entry) { #(atom(entry.0), entry.1) }))
}

fn tuple(elements: List(Dynamic)) -> Dynamic {
  dynamic.array(elements)
}

fn format(
  level: String,
  msg: Dynamic,
  meta: List(#(String, Dynamic)),
) -> String {
  map([#("level", atom(level)), #("msg", msg), #("meta", map(meta))])
  |> ffi_format(map([]))
  |> string_tree.to_string
}

fn string_msg(text: String) -> Dynamic {
  tuple([atom("string"), dynamic.string(text)])
}

fn report(fields: List(#(String, Dynamic))) -> Dynamic {
  tuple([
    atom("report"),
    dynamic.list(
      list.map(fields, fn(field) { tuple([atom(field.0), field.1]) }),
    ),
  ])
}

pub fn string_message_carries_the_request_id_test() {
  format("warning", string_msg("No route found"), [
    #("request_id", dynamic.string("abc-123")),
  ])
  |> should.equal(
    "{\"level\":\"warning\",\"msg\":\"No route found\",\"request_id\":\"abc-123\"}\n",
  )
}

pub fn request_id_is_left_out_when_unset_test() {
  format("info", string_msg("booted"), [])
  |> should.equal("{\"level\":\"info\",\"msg\":\"booted\"}\n")
}

pub fn report_fields_follow_in_order_test() {
  format(
    "info",
    report([
      #("msg", dynamic.string("request")),
      #("method", dynamic.string("GET")),
      #("path", dynamic.string("/recipes")),
      #("status", dynamic.int(200)),
      #("duration_ms", dynamic.int(4)),
    ]),
    [#("request_id", dynamic.string("abc"))],
  )
  |> should.equal(
    "{\"level\":\"info\",\"msg\":\"request\",\"request_id\":\"abc\",\"method\":\"GET\",\"path\":\"/recipes\",\"status\":200,\"duration_ms\":4}\n",
  )
}

@external(erlang, "logger", "format_otp_report")
fn format_otp_report(report: Dynamic) -> Dynamic

@external(erlang, "gleam@function", "identity")
fn to_dynamic(value: a) -> Dynamic

pub fn report_keeps_its_fields_despite_the_default_report_cb_test() {
  format(
    "info",
    report([
      #("msg", dynamic.string("request")),
      #("status", dynamic.int(200)),
    ]),
    [#("report_cb", to_dynamic(format_otp_report))],
  )
  |> should.equal("{\"level\":\"info\",\"msg\":\"request\",\"status\":200}\n")
}

pub fn report_cannot_overwrite_the_formatter_keys_test() {
  format(
    "info",
    report([
      #("msg", dynamic.string("request")),
      #("level", dynamic.string("emergency")),
      #("request_id", dynamic.string("forged")),
    ]),
    [#("request_id", dynamic.string("real"))],
  )
  |> should.equal(
    "{\"level\":\"info\",\"msg\":\"request\",\"request_id\":\"real\"}\n",
  )
}

pub fn time_is_written_as_rfc3339_test() {
  format("info", string_msg("tick"), [#("time", dynamic.int(0))])
  |> should.equal(
    "{\"time\":\"1970-01-01T00:00:00.000000Z\",\"level\":\"info\",\"msg\":\"tick\"}\n",
  )
}

pub fn every_line_is_one_valid_json_object_test() {
  let lines = [
    format("error", string_msg("line one\nline \"two\"\u{1b}[31m"), [
      #("request_id", dynamic.string("abc")),
    ]),
    format(
      "error",
      map([
        #("class", atom("error")),
        #("reason", tuple([atom("badmatch"), dynamic.int(1)])),
        #("bytes", dynamic.bit_array(<<0xFF, 0xFE>>)),
      ])
        |> fn(crash) { tuple([atom("report"), crash]) },
      [#("request_id", dynamic.string("abc"))],
    ),
    format(
      "notice",
      tuple([
        dynamic.string("~p and ~s"),
        dynamic.list([atom("x"), dynamic.string("y")]),
      ]),
      [],
    ),
  ]

  list.each(lines, fn(line) {
    let assert Ok(body) = string.split_once(line, "\n")
    body.1 |> should.equal("")
    let assert Ok(_) =
      json.parse(body.0, {
        use level <- decode.field("level", decode.string)
        use msg <- decode.field("msg", decode.string)
        decode.success(#(level, msg))
      })
  })
}
