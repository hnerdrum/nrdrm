import config/service.{type Service}
import gleam/result

pub type Match {
  Match(service: Service, path: List(String))
}

pub fn resolve(
  services: List(Service),
  segments: List(String),
) -> Result(Match, Nil) {
  case segments {
    [name, ..path] -> service.find(services, name) |> result.map(Match(_, path))
    [] -> Error(Nil)
  }
}
