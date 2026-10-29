import app/context.{type Context, Context}
import app/transport.{type Transport, type TransportError}
import config/config.{Config}
import config/env.{Dev}
import config/path_pattern.{type PathPattern}
import config/routing.{
  type Routing, type Rule, type Upstream, Bearer, Public, Route, Routing, Rule,
  Session, Upstream,
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

pub fn recipes() -> Upstream {
  upstream("recipes", "http://recipes.test/api/v1", 30_000)
}

pub fn identity() -> Upstream {
  upstream("identity", "http://identity.test/api/v1", 10_000)
}

pub fn agents() -> Upstream {
  upstream("agents", "http://agents.test", 120_000)
}

pub fn routing() -> Routing {
  Routing(
    identity: identity(),
    upstreams: [recipes(), identity(), agents()],
    routes: [
      Route(
        prefix: "recipes",
        upstream: recipes(),
        request_headers: set.from_list(["content-type", "cookie"]),
        response_headers: set.from_list(["set-cookie"]),
        rules: [
          rule("*", [Put, Delete], Session),
          rule("ingredients/*", [Put, Delete], Session),
          rule("**", [Get, Post], Public),
        ],
      ),
      Route(
        prefix: "identity",
        upstream: identity(),
        request_headers: set.from_list(["content-type", "cookie"]),
        response_headers: set.from_list(["set-cookie"]),
        rules: [rule("login", [Post], Public)],
      ),
      Route(
        prefix: "agents",
        upstream: agents(),
        request_headers: set.from_list([
          "content-type", "x-hub-signature-256", "x-github-delivery",
          "x-github-event",
        ]),
        response_headers: set.new(),
        rules: [
          rule("webhooks/github", [Post], Public),
          rule("complete", [Post], Bearer("agents")),
          rule("runs", [Post], Bearer("agents")),
          rule("runs/*", [Get], Bearer("agents")),
        ],
      ),
    ],
  )
}

fn upstream(name: String, url: String, timeout_ms: Int) -> Upstream {
  let assert Ok(base_request) = routing.parse_base_url(url)
  Upstream(name, base_request, timeout_ms)
}

fn rule(path: String, methods: List(http.Method), auth: routing.Auth) -> Rule {
  Rule(pattern(path), methods, auth)
}

fn pattern(source: String) -> PathPattern {
  let assert Ok(compiled) = path_pattern.parse(source)
  compiled
}

pub fn context(transport: Transport) -> Context {
  context_with_routing(routing(), transport)
}

pub fn context_with_routing(routing: Routing, transport: Transport) -> Context {
  Context(
    routing: routing,
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

pub fn recording_transport(
  sent: Subject(Request(BitArray)),
  respond: Responder,
) -> Transport {
  fn(req, _timeout_ms) {
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
