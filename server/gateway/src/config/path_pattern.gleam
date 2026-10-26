import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/result
import gleam/string

/// A path pattern such as `runs/*` or `ingredients/**`, compiled once when
/// config loads and matched against already-split request path segments.
pub opaque type PathPattern {
  PathPattern(segments: List(Segment))
}

type Segment {
  /// Matches exactly this segment.
  Literal(String)
  /// `*`: matches any single segment.
  Wildcard
  /// `**`: matches every remaining segment, including none. Last only.
  Rest
}

pub fn parse(pattern: String) -> Result(PathPattern, String) {
  case pattern {
    "" -> Ok(PathPattern([]))
    _ ->
      string.split(pattern, "/")
      |> parse_segments([])
      |> result.map(PathPattern)
      |> result.map_error(fn(reason) { "\"" <> pattern <> "\" " <> reason })
  }
}

fn parse_segments(
  raw: List(String),
  acc: List(Segment),
) -> Result(List(Segment), String) {
  case raw {
    [] -> Ok(list.reverse(acc))
    ["**"] -> Ok(list.reverse([Rest, ..acc]))
    ["**", ..] -> Error("has `**` before the last segment")
    ["*", ..rest] -> parse_segments(rest, [Wildcard, ..acc])
    ["", ..] -> Error("has an empty segment")
    [".", ..] | ["..", ..] -> Error("has a dot segment")
    [segment, ..rest] ->
      case string.contains(segment, "*") {
        True -> Error("has `*` inside a segment")
        False -> parse_segments(rest, [Literal(segment), ..acc])
      }
  }
}

pub fn decoder() -> Decoder(PathPattern) {
  use pattern <- decode.then(decode.string)
  case parse(pattern) {
    Ok(compiled) -> decode.success(compiled)
    Error(reason) ->
      decode.failure(PathPattern([]), "a path pattern, but " <> reason)
  }
}

pub fn matches(pattern: PathPattern, path: List(String)) -> Bool {
  match_segments(pattern.segments, path)
}

fn match_segments(segments: List(Segment), path: List(String)) -> Bool {
  case segments, path {
    [], [] -> True
    [Rest], _ -> True
    [Wildcard, ..segments], [_, ..path] -> match_segments(segments, path)
    [Literal(expected), ..segments], [actual, ..path] if expected == actual ->
      match_segments(segments, path)
    _, _ -> False
  }
}
