import gleam/string

pub fn glob_match(pattern: String, source: String, separator: String) -> Bool {
  glob_match_list(string.split(pattern, separator), string.split(source, separator))
}

fn glob_match_list(patterns: List(String), sources: List(String)) -> Bool {
  case patterns, sources {
    [], [] -> True
    [], _ -> False
    _, [] -> False
    [pattern_head, ..pattern_tail], [source_head, ..source_tail] -> {
      {pattern_head == "*" || pattern_head == source_head} &&
      glob_match_list(pattern_tail, source_tail)
    } 
  }
}