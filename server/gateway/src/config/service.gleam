import config/env.{type Environment}
import config/path_pattern.{type PathPattern}
import gleam/dynamic/decode.{type Decoder}
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import simplifile

pub type Service {
  Service(
    name: String,
    /// Parsed from `base_url` at load time; every upstream request for this
    /// service starts from it.
    base_request: Request(BitArray),
    request: RequestConfig,
    response: ResponseConfig,
    security: SecurityConfig,
  )
}

pub type RequestConfig {
  RequestConfig(forward_headers: Set(String))
}

pub type ResponseConfig {
  ResponseConfig(forward_headers: Set(String))
}

pub type SecurityConfig {
  SecurityConfig(auth: List(AuthConfig))
}

pub type Scheme {
  Cookie
  Bearer(audience: String)
}

pub type AuthConfig {
  AuthConfig(path: PathPattern, methods: List(Method), scheme: Scheme)
}

/// A request to `path` on this service, with no headers or body yet.
pub fn upstream_request(
  service: Service,
  path: List(String),
) -> Request(BitArray) {
  let base = service.base_request
  request.Request(..base, path: base.path <> "/" <> string.join(path, "/"))
}

pub fn find(services: List(Service), name: String) -> Result(Service, Nil) {
  list.find(services, fn(service) { service.name == name })
}

pub fn load_services(env: Environment) -> Result(List(Service), String) {
  let config_path = "services-" <> env.to_string(env) <> ".json"

  let contents =
    simplifile.read(config_path)
    |> result.map_error(fn(_) { "Service config file not found" })

  result.flatten(result.map(contents, parse_services))
}

pub fn parse_services(json_string: String) -> Result(List(Service), String) {
  result.map_error(
    json.parse(from: json_string, using: decode.list(service_decoder())),
    fn(err) { "Unable to parse service config: " <> describe_error(err) },
  )
}

fn describe_error(err: json.DecodeError) -> String {
  case err {
    json.UnableToDecode(errors) ->
      list.map(errors, fn(error) {
        string.join(error.path, ".")
        <> ": expected "
        <> error.expected
        <> ", found "
        <> error.found
      })
      |> string.join("; ")
    _ -> string.inspect(err)
  }
}

fn service_decoder() {
  use name <- decode.field("name", decode.string)
  use base_request <- decode.field("base_url", base_url_decoder())
  use request <- decode.field("request", service_request_decoder())
  use response <- decode.field("response", service_response_decoder())
  use security <- decode.field("security", service_security_decoder())
  decode.success(Service(
    name: name,
    base_request: base_request,
    request: request,
    response: response,
    security: security,
  ))
}

fn base_url_decoder() -> Decoder(Request(BitArray)) {
  use url <- decode.then(decode.string)
  case parse_base_url(url) {
    Ok(req) -> decode.success(req)
    Error(Nil) ->
      decode.failure(
        request.new() |> request.set_body(<<>>),
        "an absolute http(s) URL without a query string",
      )
  }
}

pub fn parse_base_url(url: String) -> Result(Request(BitArray), Nil) {
  case request.to(url) {
    Ok(request.Request(query: None, ..) as req) ->
      Ok(
        request.Request(..req, path: trim_trailing_slash(req.path))
        |> request.set_body(<<>>),
      )
    _ -> Error(Nil)
  }
}

fn trim_trailing_slash(path: String) -> String {
  case string.ends_with(path, "/") {
    True -> trim_trailing_slash(string.drop_end(path, 1))
    False -> path
  }
}

fn header_set_decoder() -> Decoder(Set(String)) {
  decode.list(decode.string)
  |> decode.map(fn(names) { set.from_list(list.map(names, string.lowercase)) })
}

fn service_request_decoder() {
  use forward_headers <- decode.field("forward_headers", header_set_decoder())
  decode.success(RequestConfig(forward_headers))
}

fn service_response_decoder() {
  use forward_headers <- decode.field("forward_headers", header_set_decoder())
  decode.success(ResponseConfig(forward_headers))
}

fn service_security_decoder() {
  use auth <- decode.field("auth", decode.list(security_auth_decoder()))
  decode.success(SecurityConfig(auth))
}

fn method_decoder() -> Decoder(Method) {
  use name <- decode.then(decode.string)
  case http.parse_method(string.uppercase(name)) {
    Ok(http.Other(_)) | Error(Nil) ->
      decode.failure(http.Get, "a standard HTTP method")
    Ok(method) -> decode.success(method)
  }
}

fn security_auth_decoder() {
  use path <- decode.field("path", path_pattern.decoder())
  use methods <- decode.field("methods", decode.list(method_decoder()))
  use scheme <- decode.optional_field("scheme", "cookie", decode.string)
  use audience <- decode.optional_field("audience", "", decode.string)
  case scheme, audience {
    "cookie", _ -> decode.success(AuthConfig(path, methods, Cookie))
    "bearer", "" ->
      decode.failure(AuthConfig(path, methods, Cookie), "audience")
    "bearer", audience ->
      decode.success(AuthConfig(path, methods, Bearer(audience)))
    _, _ -> decode.failure(AuthConfig(path, methods, Cookie), "scheme")
  }
}
