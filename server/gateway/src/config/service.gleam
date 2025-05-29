import config/env.{type Environment}
import gleam/dynamic/decode
import gleam/list
import gleam/json
import gleam/result
import simplifile

pub type Service {
  Service(
    name: String,
    base_url: String,
    request: RequestConfig,
    response: ResponseConfig,
    security: SecurityConfig
  )
}

pub type RequestConfig {
  RequestConfig(forward_headers: List(String))
}

pub type ResponseConfig {
  ResponseConfig(forward_headers: List(String))
}

pub type SecurityConfig {
  SecurityConfig(auth: List(AuthConfig))
}

pub type AuthConfig {
  AuthConfig(path: String, methods: List(String))
}

pub fn create_url(service: Service, path: String) -> String {
  service.base_url <> "/" <> path
}

pub fn find(services: List(Service), name: String) -> Result(Service, Nil) {
  list.find(services, fn(service) { service.name == name })
}

pub fn find_request_forward_header(service: Service, header_key: String) -> Result(String, Nil) {
  list.find(service.request.forward_headers, fn(header) { header == header_key })
}

pub fn find_response_forward_header(service: Service, header_key: String) -> Result(String, Nil) {
  list.find(service.response.forward_headers, fn(header) { header == header_key })
}

pub fn load_services(env: Environment) -> Result(List(Service), String) {
  let config_path = "services-" <> env.to_string(env) <> ".json"

  let contents = simplifile.read(config_path)
    |> result.map_error(fn(_) { "Service config file not found" })

  result.flatten(result.map(contents, services_from_json))
}

fn services_from_json(json_string: String) -> Result(List(Service), String) {
  result.map_error(json.parse(from: json_string, using: decode.list(service_decoder())), fn(_) { "Unable to parse JSON string into service" })
}

fn service_decoder() {
  use name <- decode.field("name", decode.string)
  use base_url <- decode.field("base_url", decode.string)
  use request <- decode.field("request", service_request_decoder())
  use response <- decode.field("response", service_response_decoder())
  use security <- decode.field("security", service_security_decoder())
  decode.success(Service(
    name: name,
    base_url: base_url,
    request: request,
    response: response,
    security: security
  ))
}

fn service_request_decoder() {
  use forward_headers <- decode.field("forward_headers", decode.list(decode.string))
  decode.success(RequestConfig(forward_headers))
}

fn service_response_decoder() {
  use forward_headers <- decode.field("forward_headers", decode.list(decode.string))
  decode.success(ResponseConfig(forward_headers))
}

fn service_security_decoder() {
  use auth <- decode.field("auth", decode.list(security_auth_decoder()))
  decode.success(SecurityConfig(auth))
}

fn security_auth_decoder() {
  use path <- decode.field("path", decode.string)
  use methods <- decode.field("methods", decode.list(decode.string))
  decode.success(AuthConfig(path, methods))
}
