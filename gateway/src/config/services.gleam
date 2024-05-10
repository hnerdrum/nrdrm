import config/env.{type Environment}
import gleam/dynamic.{field, list, string}
import gleam/json
import gleam/result
import simplifile

pub type ServiceConfig {
  ServiceConfig(name: String, base_url: String)
}

pub fn load_services(env: Environment) -> Result(List(ServiceConfig), String) {
  let config_path = "src/config/services-" <> env.to_string(env) <> ".json"

  let contents = simplifile.read(config_path)
    |> result.map_error(fn(_) { "Config file not found" })

  result.flatten(result.map(contents, services_from_json))
}

fn services_from_json(json_string: String) -> Result(List(ServiceConfig), String) {
  let services_decoder = list(
    dynamic.decode2(ServiceConfig, field("name", of: string), field("base_url", of: string))
  )

  result.map_error(json.decode(from: json_string, using: services_decoder), fn(_) { "Unable to parse string into service config" })
}

pub fn create_url(service: ServiceConfig, path: String) -> String {
  service.base_url <> "/" <> path
}
