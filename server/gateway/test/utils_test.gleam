import gleeunit/should
import utils

pub fn glob_match_path_both_empty_test() {
  utils.glob_match("", "", "/")
  |> should.equal(True)
}

pub fn glob_match_pattern_empty_test() {
  utils.glob_match("", "/test", "/")
  |> should.equal(False)
}

pub fn glob_match_path_empty_test() {
  utils.glob_match("/test", "", "/")
  |> should.equal(False)
}

pub fn glob_match_basic_case_test() {
  utils.glob_match("/test", "/test", "/")
  |> should.equal(True)
}

pub fn glob_match_nested_case_test() {
  utils.glob_match("/test/testy/test", "/test/testy/test", "/")
  |> should.equal(True)
}

pub fn glob_match_wildcard_test() {
  utils.glob_match("/test/*", "/test/testy", "/")
  |> should.equal(True)
}

pub fn glob_match_nested_wildcard_test() {
  utils.glob_match("/test/*/testy", "/test/hello/testy", "/")
  |> should.equal(True)
}

pub fn glob_match_wildcard_not_propagate_test() {
  utils.glob_match("/test/*", "/test/hello/testy", "/")
  |> should.equal(False)
}
