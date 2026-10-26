import config/env.{Dev, Prod}
import config/service
import gleam/http.{Delete, Put}
import gleam/list
import gleam/set
import gleam/string
import gleeunit/should

pub fn dev_services_config_loads_test() {
  let assert Ok(services) = service.load_services(Dev)
  list.map(services, fn(service) { service.name })
  |> should.equal(["recipes", "identity", "agents"])
}

pub fn prod_services_config_loads_test() {
  let assert Ok(services) = service.load_services(Prod)
  list.map(services, fn(service) { service.name })
  |> should.equal(["recipes", "identity", "agents"])
}

fn service_json(base_url: String, auth_path: String, method: String) -> String {
  "[{\"name\":\"recipes\",\"base_url\":\""
  <> base_url
  <> "\","
  <> "\"request\":{\"forward_headers\":[\"Content-Type\"]},"
  <> "\"response\":{\"forward_headers\":[\"Set-Cookie\"]},"
  <> "\"security\":{\"auth\":[{\"path\":\""
  <> auth_path
  <> "\","
  <> "\"methods\":[\""
  <> method
  <> "\",\"delete\"]}]}}]"
}

pub fn config_is_decoded_into_typed_values_test() {
  let assert Ok([recipes]) =
    service.parse_services(service_json(
      "http://recipes.test/api/v1/",
      "ingredients/*",
      "put",
    ))

  let upstream = service.upstream_request(recipes, ["ingredients", "flour"])
  upstream.host |> should.equal("recipes.test")
  upstream.path |> should.equal("/api/v1/ingredients/flour")
  set.to_list(recipes.request.forward_headers) |> should.equal(["content-type"])
  set.to_list(recipes.response.forward_headers) |> should.equal(["set-cookie"])
  let assert [auth] = recipes.security.auth
  auth.methods |> should.equal([Put, Delete])
}

pub fn invalid_path_pattern_fails_to_load_test() {
  let assert Error(reason) =
    service.parse_services(service_json("http://recipes.test", "runs/", "put"))
  string.contains(
    reason,
    "0.security.auth.0.path: expected a path pattern, but \"runs/\" has an empty segment",
  )
  |> should.be_true
}

pub fn invalid_base_url_fails_to_load_test() {
  let assert Error(reason) =
    service.parse_services(service_json("localhost:8000", "*", "put"))
  string.contains(
    reason,
    "0.base_url: expected an absolute http(s) URL without a query string",
  )
  |> should.be_true
}

pub fn unknown_method_fails_to_load_test() {
  let assert Error(reason) =
    service.parse_services(service_json("http://recipes.test", "*", "pots"))
  string.contains(
    reason,
    "0.security.auth.0.methods.0: expected a standard HTTP method",
  )
  |> should.be_true
}
