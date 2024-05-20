import config/env.{type Environment}
import gleam/dynamic
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
  result.map_error(json.decode(from: json_string, using: dynamic.list(service_decoder())), fn(_) { "Unable to parse JSON string into service" })
}

fn service_decoder() {
  dynamic.decode5(Service, dynamic.field("name", of: dynamic.string), dynamic.field("base_url", of: dynamic.string), dynamic.field("request", of: service_request_decoder()), dynamic.field("response", of: service_response_decoder()), dynamic.field("security", of: service_security_decoer()))
}

fn service_request_decoder() {
  dynamic.decode1(RequestConfig, dynamic.field("forward_headers", of: dynamic.list(dynamic.string)))
}

fn service_response_decoder() {
  dynamic.decode1(ResponseConfig, dynamic.field("forward_headers", of: dynamic.list(dynamic.string)))
}

fn service_security_decoer() {
  dynamic.decode1(SecurityConfig, dynamic.field("auth", of: dynamic.list(security_auth_decoder())))
}

fn security_auth_decoder() {
  dynamic.decode2(AuthConfig, dynamic.field("path", of: dynamic.string), dynamic.field("methods", of: dynamic.list(dynamic.string)))
}
