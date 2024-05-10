import config/env.{type Environment}
import gleam/dynamic.{field, list, string}
import gleam/json
import gleam/result
import simplifile

pub type Service {
  Service(name: String, base_url: String)
}

pub fn create_url(service: Service, path: String) -> String {
  service.base_url <> "/" <> path
}

pub fn load_services(env: Environment) -> Result(List(Service), String) {
  let config_path = "services-" <> env.to_string(env) <> ".json"

  let contents = simplifile.read(config_path)
    |> result.map_error(fn(_) { "Service config file not found" })

  result.flatten(result.map(contents, services_from_json))
}

fn services_from_json(json_string: String) -> Result(List(Service), String) {
  result.map_error(json.decode(from: json_string, using: list(service_decoder())), fn(_) { "Unable to parse JSON string into service" })
}

fn service_decoder() {
  dynamic.decode2(Service, field("name", of: string), field("base_url", of: string))
}
