import app/router
import config/routing
import fixture
import gleam/erlang/process
import gleam/http.{Delete, Put}
import gleam/http/request.{type Request}
import gleam/list
import gleam/set
import gleam/string
import gleeunit/should
import wisp
import wisp/testing

fn stub_env(name: String) -> Result(String, Nil) {
  case name {
    "RECIPES_URL" -> Ok("http://recipes.test")
    "IDENTITY_URL" -> Ok("http://identity.test")
    "AGENTS_URL" -> Ok("http://agents.test")
    _ -> Error(Nil)
  }
}

fn no_env(_name: String) -> Result(String, Nil) {
  Error(Nil)
}

pub fn gateway_json_loads_test() {
  let assert Ok(config) = routing.load("gateway.json", stub_env)

  config.identity.name |> should.equal("identity")
  list.map(config.routes, fn(route) { route.prefix })
  |> should.equal(["recipes", "identity", "agents"])
  list.map(config.upstreams, fn(upstream) {
    let base = upstream.base_request
    #(upstream.name, base.host <> base.path, upstream.timeout_ms)
  })
  |> should.equal([
    #("recipes", "recipes.test/api/v1", 30_000),
    #("identity", "identity.test/api/v1", 30_000),
    #("agents", "agents.test", 120_000),
  ])
}

fn status_with_gateway_json(req: wisp.Request) -> Int {
  let assert Ok(config) = routing.load("gateway.json", stub_env)
  let sent = process.new_subject()
  let identity_says_no = fn(req: Request(BitArray)) {
    case req.host {
      "identity.test" -> fixture.json(200, "{\"valid\":false,\"active\":false}")
      _ -> fixture.json(200, "{}")
    }
  }
  let ctx =
    fixture.context_with_routing(
      config,
      fixture.recording_transport(sent, identity_says_no),
    )
  router.handle_request(req, ctx).status
}

pub fn gateway_json_protects_writes_and_agent_runs_test() {
  status_with_gateway_json(testing.post("/recipes", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.post("/recipes/ingredients", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.put("/recipes/abc", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.delete("/recipes/ingredients/flour", [], ""))
  |> should.equal(401)
  status_with_gateway_json(testing.post("/agents/runs", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.get("/agents/runs/42", []))
  |> should.equal(401)
}

pub fn gateway_json_leaves_reads_and_login_public_test() {
  status_with_gateway_json(testing.get("/recipes", [])) |> should.equal(200)
  status_with_gateway_json(testing.get("/recipes/abc", [])) |> should.equal(200)
  status_with_gateway_json(testing.get("/recipes/ingredients", []))
  |> should.equal(200)
  status_with_gateway_json(testing.post("/identity/login", [], "{}"))
  |> should.equal(200)
  status_with_gateway_json(testing.post("/agents/webhooks/github", [], "{}"))
  |> should.equal(200)
}

pub fn every_missing_environment_variable_is_reported_test() {
  let assert Error(errors) = routing.load("gateway.json", no_env)
  errors
  |> should.equal([
    "gateway.json: upstream \"recipes\": environment variable RECIPES_URL is not set",
    "gateway.json: upstream \"identity\": environment variable IDENTITY_URL is not set",
    "gateway.json: upstream \"agents\": environment variable AGENTS_URL is not set",
  ])
}

fn config(identity: String, upstreams: String, routes: String) -> String {
  "{\"identity_upstream\":\""
  <> identity
  <> "\",\"upstreams\":["
  <> upstreams
  <> "],\"routes\":["
  <> routes
  <> "]}"
}

const upstream =
  "{\"name\":\"recipes\",\"url\":\"http://recipes.test/api/v1/\",\"timeout_ms\":5000}"

fn route(prefix: String, upstream: String, rules: String) -> String {
  "{\"prefix\":\""
  <> prefix
  <> "\",\"upstream\":\""
  <> upstream
  <> "\",\"request_headers\":[\"Content-Type\"],\"rules\":["
  <> rules
  <> "]}"
}

pub fn config_is_decoded_into_typed_values_test() {
  let rules =
    "{\"path\":\"ingredients/*\",\"methods\":[\"put\",\"Delete\"],\"auth\":\"session\"}"
  let assert Ok(config) =
    routing.parse(
      config("recipes", upstream, route("recipes", "recipes", rules)),
      no_env,
    )

  let assert [recipes] = config.routes
  let req = routing.upstream_request(recipes.upstream, ["ingredients", "flour"])
  req.path |> should.equal("/api/v1/ingredients/flour")
  set.to_list(recipes.request_headers) |> should.equal(["content-type"])
  set.to_list(recipes.response_headers) |> should.equal([])
  let assert [rule] = recipes.rules
  rule.methods |> should.equal([Put, Delete])
  rule.auth |> should.equal(routing.Session)
}

pub fn bearer_auth_is_decoded_test() {
  let rules =
    "{\"path\":\"runs\",\"methods\":[\"POST\"],\"auth\":{\"bearer\":{\"audience\":\"agents\"}}}"
  let assert Ok(config) =
    routing.parse(
      config("recipes", upstream, route("recipes", "recipes", rules)),
      no_env,
    )
  let assert [recipes] = config.routes
  let assert [rule] = recipes.rules
  rule.auth |> should.equal(routing.Bearer("agents"))
}

fn errors_for(json: String) -> String {
  let assert Error(errors) = routing.parse(json, stub_env)
  string.join(errors, "\n")
}

pub fn unknown_upstream_is_reported_test() {
  errors_for(config("identity", upstream, route("recipes", "recipez", "")))
  |> should.equal(
    "identity_upstream: unknown upstream \"identity\"\nroute \"recipes\": unknown upstream \"recipez\"",
  )
}

pub fn duplicate_names_are_reported_test() {
  errors_for(config(
    "recipes",
    upstream <> "," <> upstream,
    route("recipes", "recipes", "") <> "," <> route("recipes", "recipes", ""),
  ))
  |> should.equal(
    "upstream \"recipes\" is defined more than once\nroute \"recipes\" is defined more than once",
  )
}

pub fn invalid_upstream_url_is_reported_test() {
  let bad =
    "{\"name\":\"recipes\",\"url\":\"${RECIPES_URL_TYPO}localhost:8000\",\"timeout_ms\":1}"
  errors_for(config("recipes", bad, route("recipes", "recipes", "")))
  |> should.equal(
    "upstream \"recipes\": environment variable RECIPES_URL_TYPO is not set",
  )

  let bad = "{\"name\":\"recipes\",\"url\":\"localhost:8000\",\"timeout_ms\":1}"
  errors_for(config("recipes", bad, route("recipes", "recipes", "")))
  |> should.equal(
    "upstream \"recipes\": url \"localhost:8000\" is not an absolute http(s) URL without a query string",
  )
}

pub fn malformed_fields_are_all_reported_test() {
  let bad_upstream =
    "{\"name\":\"recipes\",\"url\":\"http://recipes.test\",\"timeout_ms\":0}"
  let bad_rule =
    "{\"path\":\"runs/\",\"methods\":[\"pots\"],\"auth\":\"sometimes\"}"
  let errors =
    errors_for(config(
      "recipes",
      bad_upstream,
      route("health", "recipes", bad_rule),
    ))

  string.contains(errors, "upstreams.0.timeout_ms: expected a positive integer")
  |> should.be_true
  string.contains(
    errors,
    "routes.0.prefix: expected a prefix other than the reserved \"health\"",
  )
  |> should.be_true
  string.contains(
    errors,
    "routes.0.rules.0.path: expected a path pattern, but \"runs/\" has an empty segment",
  )
  |> should.be_true
  string.contains(
    errors,
    "routes.0.rules.0.methods.0: expected a standard HTTP method",
  )
  |> should.be_true
  string.contains(errors, "routes.0.rules.0.auth: expected \"public\"")
  |> should.be_true
}
