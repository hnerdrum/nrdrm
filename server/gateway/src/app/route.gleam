import config/routing.{type Route}
import gleam/list
import gleam/result

pub type Match {
  Match(route: Route, path: List(String))
}

pub fn resolve(
  routes: List(Route),
  segments: List(String),
) -> Result(Match, Nil) {
  case segments {
    [prefix, ..path] ->
      list.find(routes, fn(route) { route.prefix == prefix })
      |> result.map(Match(_, path))
    [] -> Error(Nil)
  }
}
