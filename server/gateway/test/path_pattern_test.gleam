import config/path_pattern
import gleeunit/should

fn matches(pattern: String, path: List(String)) -> Bool {
  let assert Ok(compiled) = path_pattern.parse(pattern)
  path_pattern.matches(compiled, path)
}

pub fn empty_pattern_matches_only_the_root_test() {
  matches("", []) |> should.be_true
  matches("", ["runs"]) |> should.be_false
}

pub fn literal_segments_match_exactly_test() {
  matches("runs", ["runs"]) |> should.be_true
  matches("oauth/introspect", ["oauth", "introspect"]) |> should.be_true
  matches("runs", ["run"]) |> should.be_false
  matches("runs", ["runs", "42"]) |> should.be_false
  matches("oauth/introspect", ["oauth"]) |> should.be_false
}

pub fn wildcard_matches_exactly_one_segment_test() {
  matches("runs/*", ["runs", "42"]) |> should.be_true
  matches("*/items", ["cart", "items"]) |> should.be_true
  matches("runs/*", ["runs"]) |> should.be_false
  matches("runs/*", ["runs", "42", "logs"]) |> should.be_false
  matches("*", []) |> should.be_false
}

pub fn rest_matches_any_remaining_segments_test() {
  matches("ingredients/**", ["ingredients"]) |> should.be_true
  matches("ingredients/**", ["ingredients", "flour"]) |> should.be_true
  matches("ingredients/**", ["ingredients", "flour", "x"]) |> should.be_true
  matches("ingredients/**", ["recipes", "flour"]) |> should.be_false
  matches("**", []) |> should.be_true
}

pub fn malformed_patterns_are_rejected_test() {
  path_pattern.parse("/runs") |> should.be_error
  path_pattern.parse("runs/") |> should.be_error
  path_pattern.parse("runs//42") |> should.be_error
  path_pattern.parse("runs/../admin") |> should.be_error
  path_pattern.parse("runs/*.json") |> should.be_error
  path_pattern.parse("**/runs") |> should.be_error
}
