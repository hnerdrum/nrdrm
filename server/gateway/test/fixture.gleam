import app/context.{type Context, Context}
import app/transport.{type Transport, type TransportError}
import config/config.{Config}
import config/env.{Dev}
import config/path_pattern.{type PathPattern}
import config/service.{
  type Service, AuthConfig, Bearer, Cookie, RequestConfig, ResponseConfig,
  SecurityConfig, Service,
}
import gleam/bit_array
import gleam/erlang/process.{type Subject}
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/set

pub type Responder =
  fn(Request(BitArray)) -> Result(Response(BitArray), TransportError)

pub fn recipes() -> Service {
  Service(
    name: "recipes",
    base_request: base_url("http://recipes.test/api/v1"),
    request: RequestConfig(set.from_list(["content-type", "cookie"])),
    response: ResponseConfig(set.from_list(["set-cookie"])),
    security: SecurityConfig([
      AuthConfig(pattern("*"), [Put, Delete], Cookie),
      AuthConfig(pattern("ingredients/*"), [Put, Delete], Cookie),
    ]),
  )
}

pub fn identity() -> Service {
  Service(
    name: "identity",
    base_request: base_url("http://identity.test/api/v1"),
    request: RequestConfig(set.from_list(["content-type", "cookie"])),
    response: ResponseConfig(set.from_list(["set-cookie"])),
    security: SecurityConfig([]),
  )
}

pub fn agents() -> Service {
  Service(
    name: "agents",
    base_request: base_url("http://agents.test"),
    request: RequestConfig(
      set.from_list([
        "content-type", "x-nrdrm-client", "x-hub-signature-256",
        "x-github-delivery", "x-github-event",
      ]),
    ),
    response: ResponseConfig(set.new()),
    security: SecurityConfig([
      AuthConfig(pattern("complete"), [Post], Bearer("agents")),
      AuthConfig(pattern("runs"), [Post], Bearer("agents")),
      AuthConfig(pattern("runs/*"), [Get], Bearer("agents")),
    ]),
  )
}

fn base_url(url: String) -> Request(BitArray) {
  let assert Ok(req) = service.parse_base_url(url)
  req
}

fn pattern(source: String) -> PathPattern {
  let assert Ok(compiled) = path_pattern.parse(source)
  compiled
}

pub fn context(transport: Transport) -> Context {
  Context(
    services: [recipes(), identity(), agents()],
    identity_service: identity(),
    config: Config(
      port: 8080,
      secret_key_base: "test-secret-key-base",
      env: Dev,
      allowed_origins: ["http://localhost:3000"],
      boot_time: "2026-01-01T00:00:00Z",
      api_version: "test",
    ),
    transport: transport,
  )
}

/// A fake transport that answers with `respond` and records every request it
/// receives on `sent`, so tests can assert what the gateway sent upstream.
pub fn recording_transport(
  sent: Subject(Request(BitArray)),
  respond: Responder,
) -> Transport {
  fn(req) {
    process.send(sent, req)
    respond(req)
  }
}

pub fn sent_requests(
  sent: Subject(Request(BitArray)),
) -> List(Request(BitArray)) {
  drain(sent, [])
}

fn drain(
  sent: Subject(Request(BitArray)),
  acc: List(Request(BitArray)),
) -> List(Request(BitArray)) {
  case process.receive(sent, 0) {
    Ok(req) -> drain(sent, [req, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}

pub fn json(
  status: Int,
  body: String,
) -> Result(Response(BitArray), TransportError) {
  Ok(
    response.new(status)
    |> response.set_header("content-type", "application/json")
    |> response.set_body(bit_array.from_string(body)),
  )
}
