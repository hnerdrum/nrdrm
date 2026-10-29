import gleam/list
import gleam/string

pub fn interpolate(
  template: String,
  lookup: fn(String) -> Result(String, Nil),
) -> Result(String, List(String)) {
  interpolate_loop(template, lookup, "", [])
}

fn interpolate_loop(
  rest: String,
  lookup: fn(String) -> Result(String, Nil),
  output: String,
  errors: List(String),
) -> Result(String, List(String)) {
  case string.split_once(rest, "${") {
    Error(Nil) ->
      case errors {
        [] -> Ok(output <> rest)
        _ -> Error(list.reverse(errors))
      }
    Ok(#(before, after)) ->
      case string.split_once(after, "}") {
        Error(Nil) -> Error(list.reverse(["unterminated \"${\"", ..errors]))
        Ok(#(name, rest)) ->
          case lookup(name) {
            Ok(value) if value != "" ->
              interpolate_loop(rest, lookup, output <> before <> value, errors)
            _ ->
              interpolate_loop(rest, lookup, output, [
                "environment variable " <> name <> " is not set",
                ..errors
              ])
          }
      }
  }
}
