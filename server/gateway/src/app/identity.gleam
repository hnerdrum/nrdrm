import app/request_id
import app/transport.{type Transport}
import config/routing.{type Upstream}
import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/option.{type Option, None}
import gleam/result
import gleam/string
import wisp.{type Request}

pub type Introspection {
  Introspection(
    active: Bool,
    audience: Option(String),
    client_name: Option(String),
  )
}

pub fn validate_session(
  transport: Transport,
  identity: Upstream,
  incoming_request: Request,
) -> Bool {
  let req =
    routing.upstream_request(identity, ["validate-token"])
    |> request_id.propagate(incoming_request)
  let req = case request.get_header(incoming_request, "cookie") {
    Ok(cookie) -> request.set_header(req, "cookie", cookie)
    Error(Nil) -> req
  }
  case transport(req, identity.timeout_ms) {
    Ok(response.Response(status: 200, body: body, ..)) ->
      json.parse_bits(body, valid_decoder()) |> result.unwrap(False)
    _ -> False
  }
}

pub fn introspect(
  transport: Transport,
  identity: Upstream,
  incoming_request: Request,
) -> Result(Introspection, Nil) {
  use token <- result.try(bearer_token(incoming_request))
  let body =
    json.object([#("token", json.string(token))])
    |> json.to_string
    |> bit_array.from_string
  let req =
    routing.upstream_request(identity, ["oauth", "introspect"])
    |> request_id.propagate(incoming_request)
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)
  case transport(req, identity.timeout_ms) {
    Ok(response.Response(status: 200, body: body, ..)) ->
      json.parse_bits(body, introspection_decoder())
      |> result.replace_error(Nil)
    _ -> Error(Nil)
  }
}

fn bearer_token(req: Request) -> Result(String, Nil) {
  use header <- result.try(request.get_header(req, "authorization"))
  use #(scheme, token) <- result.try(string.split_once(string.trim(header), " "))
  case string.lowercase(scheme), string.trim(token) {
    "bearer", "" -> Error(Nil)
    "bearer", token -> Ok(token)
    _, _ -> Error(Nil)
  }
}

fn valid_decoder() -> decode.Decoder(Bool) {
  use valid <- decode.field("valid", decode.bool)
  decode.success(valid)
}

fn introspection_decoder() -> decode.Decoder(Introspection) {
  use active <- decode.field("active", decode.bool)
  use audience <- decode.optional_field(
    "aud",
    None,
    decode.optional(decode.string),
  )
  use client_name <- decode.optional_field(
    "client_name",
    None,
    decode.optional(decode.string),
  )
  decode.success(Introspection(active, audience, client_name))
}
