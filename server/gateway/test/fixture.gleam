import app/context.{type Context, Context}
import app/transport.{type Transport, type TransportError}
import config/config.{Config}
import config/env.{Dev}
import config/service.{
  type Service, AuthConfig, Bearer, Cookie, RequestConfig, ResponseConfig,
  SecurityConfig, Service,
}
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list

pub type Responder =
  fn(Request(String)) -> Result(Response(String), TransportError)

pub fn recipes() -> Service {
  Service(
    name: "recipes",
    base_url: "http://recipes.test/api/v1",
    request: RequestConfig(["content-type", "cookie"]),
    response: ResponseConfig(["set-cookie"]),
    security: SecurityConfig([
      AuthConfig("*", ["put", "delete"], Cookie),
      AuthConfig("ingredients/*", ["put", "delete"], Cookie),
    ]),
  )
}

pub fn identity() -> Service {
  Service(
    name: "identity",
    base_url: "http://identity.test/api/v1",
    request: RequestConfig(["content-type", "cookie"]),
    response: ResponseConfig(["set-cookie"]),
    security: SecurityConfig([]),
  )
}

pub fn agents() -> Service {
  Service(
    name: "agents",
    base_url: "http://agents.test",
    request: RequestConfig([
      "content-type", "x-nrdrm-client", "x-hub-signature-256",
      "x-github-delivery", "x-github-event",
    ]),
    response: ResponseConfig([]),
    security: SecurityConfig([
      AuthConfig("complete", ["post"], Bearer("agents")),
      AuthConfig("runs", ["post"], Bearer("agents")),
      AuthConfig("runs/*", ["get"], Bearer("agents")),
    ]),
  )
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
  sent: Subject(Request(String)),
  respond: Responder,
) -> Transport {
  fn(req) {
    process.send(sent, req)
    respond(req)
  }
}

pub fn sent_requests(sent: Subject(Request(String))) -> List(Request(String)) {
  drain(sent, [])
}

fn drain(
  sent: Subject(Request(String)),
  acc: List(Request(String)),
) -> List(Request(String)) {
  case process.receive(sent, 0) {
    Ok(req) -> drain(sent, [req, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}

pub fn json(
  status: Int,
  body: String,
) -> Result(Response(String), TransportError) {
  Ok(
    response.new(status)
    |> response.set_header("content-type", "application/json")
    |> response.set_body(body),
  )
}
