import app/router
import app/transport
import config/routing
import fixture
import gleam/erlang/process
import gleam/http.{Delete, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/list
import gleam/option.{None, Some}
import gleam/set
import gleam/string
import gleeunit/should
import wisp
import wisp/testing

const mcp_resource_url = "http://localhost:8080/training/mcp"

const mcp_challenge =
  "Bearer resource_metadata=\"http://localhost:8080/training/oauth-protected-resource\", scope=\"training\""

fn stub_env(name: String) -> Result(String, Nil) {
  case name {
    "RECIPES_URL" -> Ok("http://recipes.test")
    "IDENTITY_URL" -> Ok("http://identity.test")
    "AGENTS_URL" -> Ok("http://agents.test")
    "TRAINING_URL" -> Ok("http://training.test")
    "MCP_RESOURCE_URL" -> Ok(mcp_resource_url)
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
  |> should.equal(["recipes", "identity", "agents", "training", ".well-known"])
  let assert Ok(training) =
    list.find(config.routes, fn(route) { route.prefix == "training" })
  list.any(training.rules, fn(rule) {
    rule.methods == [Post]
    && rule.auth == routing.Bearer(mcp_resource_url, Some("training"))
  })
  |> should.be_true
  set.contains(training.request_headers, "authorization") |> should.be_false
  set.contains(training.request_headers, "accept") |> should.be_true
  set.contains(training.request_headers, "origin") |> should.be_true
  set.contains(training.request_headers, "mcp-protocol-version")
  |> should.be_true
  let assert Ok(identity) =
    list.find(config.routes, fn(route) { route.prefix == "identity" })
  set.contains(identity.response_headers, "location") |> should.be_true
  set.contains(identity.response_headers, "content-security-policy")
  |> should.be_true
  set.contains(identity.response_headers, "referrer-policy") |> should.be_true
  set.contains(identity.response_headers, "cache-control") |> should.be_true
  list.map(config.upstreams, fn(upstream) {
    let base = upstream.base_request
    #(upstream.name, base.host <> base.path, upstream.timeout_ms)
  })
  |> should.equal([
    #("recipes", "recipes.test/api/v1", 30_000),
    #("identity", "identity.test/api/v1", 30_000),
    #("agents", "agents.test", 120_000),
    #("training", "training.test/api", 30_000),
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
  status_with_gateway_json(testing.put("/recipes/abc", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.delete("/recipes/ingredients/flour", [], ""))
  |> should.equal(401)
  status_with_gateway_json(testing.post("/agents/runs", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.get("/agents/runs/42", []))
  |> should.equal(401)
}

pub fn gateway_json_leaves_reads_creates_and_login_public_test() {
  status_with_gateway_json(testing.get("/recipes", [])) |> should.equal(200)
  status_with_gateway_json(testing.get("/recipes/abc", [])) |> should.equal(200)
  status_with_gateway_json(testing.get("/recipes/ingredients", []))
  |> should.equal(200)
  status_with_gateway_json(testing.post("/recipes", [], "{}"))
  |> should.equal(200)
  status_with_gateway_json(testing.post("/recipes/ingredients", [], "{}"))
  |> should.equal(200)
  status_with_gateway_json(testing.get("/identity/me", [])) |> should.equal(200)
  status_with_gateway_json(testing.post("/identity/login", [], "{}"))
  |> should.equal(200)
  status_with_gateway_json(testing.post("/identity/logout", [], ""))
  |> should.equal(200)
  status_with_gateway_json(testing.post("/agents/webhooks/github", [], "{}"))
  |> should.equal(200)
  status_with_gateway_json(testing.get("/training/health", []))
  |> should.equal(200)
}

pub fn gateway_json_requires_a_session_for_training_sessions_test() {
  status_with_gateway_json(testing.post("/training/sync", [], ""))
  |> should.equal(401)
  status_with_gateway_json(testing.get("/training/sessions", []))
  |> should.equal(401)
  status_with_gateway_json(testing.post("/training/sessions", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.get("/training/sessions/abc", []))
  |> should.equal(401)
  status_with_gateway_json(testing.put("/training/sessions/abc", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.delete("/training/sessions/abc", [], ""))
  |> should.equal(401)
}

pub fn gateway_json_requires_a_session_for_training_presets_test() {
  status_with_gateway_json(testing.get("/training/presets", []))
  |> should.equal(401)
  status_with_gateway_json(testing.post("/training/presets", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.get("/training/presets/abc", []))
  |> should.equal(401)
  status_with_gateway_json(testing.put("/training/presets/abc", [], "{}"))
  |> should.equal(401)
  status_with_gateway_json(testing.delete("/training/presets/abc", [], ""))
  |> should.equal(401)
}

pub fn gateway_json_hides_everything_it_does_not_list_test() {
  status_with_gateway_json(testing.get("/identity/validate-token", []))
  |> should.equal(404)
  status_with_gateway_json(testing.post("/identity/oauth/introspect", [], "{}"))
  |> should.equal(404)
  status_with_gateway_json(testing.patch("/recipes/abc", [], "{}"))
  |> should.equal(404)
  status_with_gateway_json(testing.get("/agents/unlisted", []))
  |> should.equal(404)
  status_with_gateway_json(testing.get("/training/me", [])) |> should.equal(404)
  status_with_gateway_json(testing.get("/training/sync", []))
  |> should.equal(404)
  status_with_gateway_json(testing.patch("/training/sessions/abc", [], "{}"))
  |> should.equal(404)
  status_with_gateway_json(testing.patch("/training/presets/abc", [], "{}"))
  |> should.equal(404)
}

pub fn every_missing_environment_variable_is_reported_test() {
  let assert Error(errors) = routing.load("gateway.json", no_env)
  errors
  |> should.equal([
    "gateway.json: upstream \"recipes\": environment variable RECIPES_URL is not set",
    "gateway.json: upstream \"identity\": environment variable IDENTITY_URL is not set",
    "gateway.json: upstream \"agents\": environment variable AGENTS_URL is not set",
    "gateway.json: upstream \"training\": environment variable TRAINING_URL is not set",
    "gateway.json: route \"training\": environment variable MCP_RESOURCE_URL is not set",
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
  rule.auth |> should.equal(routing.Bearer("agents", None))
}

pub fn scoped_bearer_audience_is_interpolated_test() {
  let rules =
    "{\"path\":\"mcp\",\"methods\":[\"POST\"],\"auth\":{\"bearer\":{\"audience\":\"${MCP_RESOURCE_URL}\",\"scope\":\"training\"}}}"
  let assert Ok(config) =
    routing.parse(
      config("recipes", upstream, route("training", "recipes", rules)),
      fn(name) {
        case name {
          "MCP_RESOURCE_URL" -> Ok(mcp_resource_url)
          _ -> Error(Nil)
        }
      },
    )
  let assert [training] = config.routes
  let assert [rule] = training.rules
  rule.auth |> should.equal(routing.Bearer(mcp_resource_url, Some("training")))
}

pub fn scoped_bearer_audience_requires_its_environment_variable_test() {
  let rules =
    "{\"path\":\"mcp\",\"methods\":[\"POST\"],\"auth\":{\"bearer\":{\"audience\":\"${MCP_RESOURCE_URL}\",\"scope\":\"training\"}}}"
  let assert Error(errors) =
    routing.parse(
      config("recipes", upstream, route("training", "recipes", rules)),
      no_env,
    )
  errors
  |> should.equal([
    "route \"training\": environment variable MCP_RESOURCE_URL is not set",
  ])
}

pub fn scoped_bearer_audience_must_end_with_mcp_test() {
  let rules =
    "{\"path\":\"mcp\",\"methods\":[\"POST\"],\"auth\":{\"bearer\":{\"audience\":\"http://localhost:8080/training\",\"scope\":\"training\"}}}"
  errors_for(config("recipes", upstream, route("training", "recipes", rules)))
  |> should.equal(
    "route \"training\": audience \"http://localhost:8080/training\" must end with /mcp",
  )
}

pub fn empty_bearer_scope_is_rejected_test() {
  let rules =
    "{\"path\":\"mcp\",\"methods\":[\"POST\"],\"auth\":{\"bearer\":{\"audience\":\"http://localhost:8080/training/mcp\",\"scope\":\"\"}}}"
  errors_for(config("recipes", upstream, route("training", "recipes", rules)))
  |> string.contains("rules.0.auth")
  |> should.be_true
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
      route("_gateway", "recipes", bad_rule),
    ))

  string.contains(errors, "upstreams.0.timeout_ms: expected a positive integer")
  |> should.be_true
  string.contains(
    errors,
    "routes.0.prefix: expected a prefix other than the reserved \"_gateway\"",
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

fn call_gateway_json(
  req: wisp.Request,
  respond: fn(Request(BitArray)) ->
    Result(response.Response(BitArray), transport.TransportError),
) -> #(wisp.Response, List(Request(BitArray))) {
  let assert Ok(config) = routing.load("gateway.json", stub_env)
  let sent = process.new_subject()
  let ctx =
    fixture.context_with_routing(
      config,
      fixture.recording_transport(sent, respond),
    )
  #(router.handle_request(req, ctx), fixture.sent_requests(sent))
}

pub fn gateway_json_publishes_mcp_sign_in_routes_test() {
  let #(metadata, metadata_sent) =
    call_gateway_json(
      testing.get("/training/oauth-protected-resource", []),
      fn(_) { fixture.json(200, "{}") },
    )
  metadata.status |> should.equal(200)
  let assert [metadata_upstream] = metadata_sent
  metadata_upstream.host |> should.equal("training.test")
  metadata_upstream.path |> should.equal("/api/oauth-protected-resource")

  let #(register, register_sent) =
    call_gateway_json(testing.post("/identity/oauth/register", [], "{}"), fn(_) {
      fixture.json(201, "{}")
    })
  register.status |> should.equal(201)
  let assert [register_upstream] = register_sent
  register_upstream.path |> should.equal("/api/v1/oauth/register")

  let #(authorize, authorize_sent) =
    call_gateway_json(
      testing.get("/identity/oauth/authorize?client_id=cursor", []),
      fn(_) { fixture.json(200, "page") },
    )
  authorize.status |> should.equal(200)
  let assert [authorize_upstream] = authorize_sent
  authorize_upstream.path |> should.equal("/api/v1/oauth/authorize")
  authorize_upstream.query |> should.equal(Some("client_id=cursor"))

  let #(token, token_sent) =
    call_gateway_json(
      testing.post("/identity/oauth/token", [], "grant=code"),
      fn(_) { fixture.json(200, "{}") },
    )
  token.status |> should.equal(200)
  let assert [token_upstream] = token_sent
  token_upstream.path |> should.equal("/api/v1/oauth/token")

  let #(metadata_doc, metadata_doc_sent) =
    call_gateway_json(
      testing.get("/.well-known/oauth-authorization-server/identity", []),
      fn(_) { fixture.json(200, "{}") },
    )
  metadata_doc.status |> should.equal(200)
  let assert [metadata_doc_upstream] = metadata_doc_sent
  metadata_doc_upstream.host |> should.equal("identity.test")
  metadata_doc_upstream.path
  |> should.equal("/api/v1/oauth-authorization-server/identity")
}

pub fn identity_redirect_headers_reach_the_caller_test() {
  let #(response, sent) =
    call_gateway_json(
      testing.get("/identity/oauth/authorize?client_id=cursor", []),
      fn(_) {
        Ok(
          response.new(303)
          |> response.set_header("location", "cursor://done?code=1")
          |> response.set_header(
            "content-security-policy",
            "frame-ancestors 'none'",
          )
          |> response.set_header("referrer-policy", "no-referrer")
          |> response.set_header("cache-control", "no-store")
          |> response.set_body(<<>>),
        )
      },
    )

  response.status |> should.equal(303)
  response.get_header(response, "location")
  |> should.equal(Ok("cursor://done?code=1"))
  response.get_header(response, "content-security-policy")
  |> should.equal(Ok("frame-ancestors 'none'"))
  response.get_header(response, "referrer-policy")
  |> should.equal(Ok("no-referrer"))
  response.get_header(response, "cache-control") |> should.equal(Ok("no-store"))
  let assert [upstream] = sent
  upstream.host |> should.equal("identity.test")
}

pub fn mcp_without_a_token_is_a_sign_in_challenge_test() {
  let #(response, sent) =
    call_gateway_json(testing.post("/training/mcp", [], "{}"), fn(_) {
      fixture.json(200, "{}")
    })

  response.status |> should.equal(401)
  response.get_header(response, "www-authenticate")
  |> should.equal(Ok(mcp_challenge))
  sent |> should.equal([])
}

pub fn mcp_get_and_delete_are_method_not_allowed_test() {
  let #(get, get_sent) =
    call_gateway_json(testing.get("/training/mcp", []), fn(_) {
      fixture.json(200, "{}")
    })
  get.status |> should.equal(405)
  response.get_header(get, "allow") |> should.equal(Ok("POST"))
  get_sent |> should.equal([])

  let #(delete, delete_sent) =
    call_gateway_json(testing.delete("/training/mcp", [], ""), fn(_) {
      fixture.json(200, "{}")
    })
  delete.status |> should.equal(405)
  delete_sent |> should.equal([])
}

pub fn mcp_with_the_owners_token_forwards_the_email_test() {
  let #(response, sent) =
    call_gateway_json(
      testing.post(
        "/training/mcp",
        [
          #("authorization", "Bearer caller-token"),
          #("content-type", "application/json"),
          #("accept", "application/json, text/event-stream"),
          #("mcp-protocol-version", "2026-07-28"),
          #("origin", "https://nrdrm.no"),
          #("x-nrdrm-email", "spoofed@example.com"),
          #("cookie", "session=abc"),
        ],
        "{\"jsonrpc\":\"2.0\"}",
      ),
      fn(req) {
        case req.host {
          "identity.test" ->
            fixture.json(
              200,
              "{\"active\":true,\"aud\":\""
                <> mcp_resource_url
                <> "\",\"scope\":\"read training\",\"email\":\" ada@example.com \",\"client_name\":\"Cursor\"}",
            )
          _ -> fixture.json(200, "{\"ok\":true}")
        }
      },
    )

  response.status |> should.equal(200)
  let assert [introspection, upstream] = sent
  introspection.path |> should.equal("/api/v1/oauth/introspect")
  introspection.body |> should.equal(<<"{\"token\":\"caller-token\"}":utf8>>)
  upstream.host |> should.equal("training.test")
  upstream.path |> should.equal("/api/mcp")
  upstream.body |> should.equal(<<"{\"jsonrpc\":\"2.0\"}":utf8>>)
  request.get_header(upstream, "x-nrdrm-email")
  |> should.equal(Ok("ada@example.com"))
  request.get_header(upstream, "x-nrdrm-client") |> should.equal(Error(Nil))
  request.get_header(upstream, "authorization") |> should.equal(Error(Nil))
  request.get_header(upstream, "accept")
  |> should.equal(Ok("application/json, text/event-stream"))
  request.get_header(upstream, "mcp-protocol-version")
  |> should.equal(Ok("2026-07-28"))
  request.get_header(upstream, "origin") |> should.equal(Ok("https://nrdrm.no"))
  request.get_header(upstream, "content-type")
  |> should.equal(Ok("application/json"))
  request.get_header(upstream, "cookie") |> should.equal(Ok("session=abc"))
}

pub fn mcp_rejects_a_token_that_is_not_for_the_log_test() {
  let inactive =
    call_gateway_json(
      testing.post("/training/mcp", [#("authorization", "Bearer token")], "{}"),
      fn(_) { fixture.json(200, "{\"active\":false}") },
    )
  inactive.0.status |> should.equal(401)
  response.get_header(inactive.0, "www-authenticate")
  |> should.equal(Ok(mcp_challenge))

  let other_audience =
    call_gateway_json(
      testing.post("/training/mcp", [#("authorization", "Bearer token")], "{}"),
      fn(_) {
        fixture.json(
          200,
          "{\"active\":true,\"aud\":\"agents\",\"scope\":\"training\",\"email\":\"ada@example.com\"}",
        )
      },
    )
  other_audience.0.status |> should.equal(401)
  response.get_header(other_audience.0, "www-authenticate")
  |> should.equal(Ok(mcp_challenge))

  let other_scope =
    call_gateway_json(
      testing.post("/training/mcp", [#("authorization", "Bearer token")], "{}"),
      fn(_) {
        fixture.json(
          200,
          "{\"active\":true,\"aud\":\""
            <> mcp_resource_url
            <> "\",\"scope\":\"profile\",\"email\":\"ada@example.com\"}",
        )
      },
    )
  other_scope.0.status |> should.equal(401)

  let no_email =
    call_gateway_json(
      testing.post("/training/mcp", [#("authorization", "Bearer token")], "{}"),
      fn(_) {
        fixture.json(
          200,
          "{\"active\":true,\"aud\":\""
            <> mcp_resource_url
            <> "\",\"scope\":\"training\"}",
        )
      },
    )
  no_email.0.status |> should.equal(401)
  list.length(no_email.1) |> should.equal(1)
}

pub fn mcp_is_unavailable_when_identity_cannot_be_reached_test() {
  let #(response, sent) =
    call_gateway_json(
      testing.post("/training/mcp", [#("authorization", "Bearer token")], "{}"),
      fn(_) { Error(transport.Timeout) },
    )

  response.status |> should.equal(503)
  testing.string_body(response) |> should.equal("Unavailable")
  response.get_header(response, "www-authenticate") |> should.equal(Error(Nil))
  let assert [introspection] = sent
  introspection.host |> should.equal("identity.test")
}

pub fn agents_bearer_stays_unauthorized_when_identity_is_down_test() {
  let #(response, _) =
    call_gateway_json(
      testing.post("/agents/runs", [#("authorization", "Bearer token")], "{}"),
      fn(_) { Error(transport.FailedToConnect("down")) },
    )

  response.status |> should.equal(401)
  response.get_header(response, "www-authenticate") |> should.equal(Error(Nil))
}
