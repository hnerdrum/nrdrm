import gleam/string


pub fn glob_match_path(pattern: String, path: String) -> Bool {
  let pattern_parts = string.split(pattern, "/")
  let path_parts = string.split(path, "/")

  case pattern_parts, path_parts {
    [], [] -> True
    [""], [""] -> True
    [], _ -> False
    _, [] -> False
    [pattern_head, ..pattern_tail], [path_head, ..path_tail] -> {
      {pattern_head == "*" || pattern_head == path_head} &&
      glob_match_path(string.join(pattern_tail, "/"), string.join(path_tail, "/"))
    } 
  }
}