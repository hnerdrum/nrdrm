import gleeunit/should
import utils

pub fn glob_match_path_both_empty_test() {
  utils.glob_match_path("", "")
  |> should.equal(True)
}

pub fn glob_match_path_pattern_empty_test() {
  utils.glob_match_path("", "/test")
  |> should.equal(False)
}

pub fn glob_match_path_path_empty_test() {
  utils.glob_match_path("/test", "")
  |> should.equal(False)
}

pub fn glob_match_path_basic_case_test() {
  utils.glob_match_path("/test", "/test")
  |> should.equal(True)
}

pub fn glob_match_path_nested_case_test() {
  utils.glob_match_path("/test/testy/test", "/test/testy/test")
  |> should.equal(True)
}

pub fn glob_match_path_wildcard_test() {
  utils.glob_match_path("/test/*", "/test/testy")
  |> should.equal(True)
}

pub fn glob_match_path_nested_wildcard_test() {
  utils.glob_match_path("/test/*/testy", "/test/hello/testy")
  |> should.equal(True)
}

pub fn glob_match_path_wildcard_not_propagate_test() {
  utils.glob_match_path("/test/*", "/test/hello/testy")
  |> should.equal(False)
}
