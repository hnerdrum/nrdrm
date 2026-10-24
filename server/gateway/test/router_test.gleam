import app/router
import app/transport
import fixture
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/string
import gleeunit/should
import wisp
import wisp/testing

fn run(
  req: wisp.Request,
  respond: fixture.Responder,
) -> #(wisp.Response, List(Request(String))) {
  let sent = process.new_subject()
  let ctx = fixture.context(fixture.recording_transport(sent, respond))
  let response = router.handle_request(req, ctx)
  #(response, fixture.sent_requests(sent))
}

fn identity_and_upstream(identity_body: String) -> fixture.Responder {
  fn(req: Request(String)) {
    case req.host {
      "identity.test" -> fixture.json(200, identity_body)
      _ -> fixture.json(200, "{\"ok\":true}")
    }
  }
}

pub fn public_request_is_forwarded_to_service_test() {
  let #(response, sent) =
    run(testing.get("/recipes/pancakes", []), fn(_) {
      fixture.json(200, "{\"name\":\"pancakes\"}")
    })

  response.status |> should.equal(200)
  testing.string_body(response) |> should.equal("{\"name\":\"pancakes\"}")
  let assert [upstream] = sent
  upstream.method |> should.equal(http.Get)
  upstream.host |> should.equal("recipes.test")
  upstream.path |> should.equal("/api/v1/pancakes")
}

pub fn request_body_is_forwarded_test() {
  let #(_, sent) =
    run(
      testing.post(
        "/agents/webhooks/github",
        [#("content-type", "application/json")],
        "{\"action\":\"opened\"}",
      ),
      fn(_) { fixture.json(202, "{}") },
    )

  let assert [upstream] = sent
  upstream.method |> should.equal(http.Post)
  upstream.body |> should.equal("{\"action\":\"opened\"}")
  request.get_header(upstream, "content-type")
  |> should.equal(Ok("application/json"))
}

pub fn headers_outside_the_allowlist_are_not_forwarded_test() {
  let #(_, sent) =
    run(
      testing.get("/recipes/pancakes", [
        #("cookie", "session=abc"),
        #("x-secret", "nope"),
      ]),
      fn(_) { fixture.json(200, "{}") },
    )

  let assert [upstream] = sent
  request.get_header(upstream, "cookie") |> should.equal(Ok("session=abc"))
  request.get_header(upstream, "x-secret") |> should.equal(Error(Nil))
}

pub fn method_override_query_is_ignored_test() {
  let #(response, sent) =
    run(testing.post("/recipes/pancakes?_method=DELETE", [], ""), fn(_) {
      fixture.json(200, "{}")
    })

  response.status |> should.equal(200)
  let assert [upstream] = sent
  upstream.method |> should.equal(http.Post)
}

pub fn unknown_service_is_not_found_test() {
  let #(response, sent) =
    run(testing.get("/nope/anything", []), fn(_) { fixture.json(200, "{}") })

  response.status |> should.equal(404)
  sent |> should.equal([])
}

pub fn upstream_connection_failure_is_internal_server_error_test() {
  let #(response, _) =
    run(testing.get("/recipes/pancakes", []), fn(_) {
      Error(transport.FailedToConnect("econnrefused"))
    })

  response.status |> should.equal(500)
}

pub fn cookie_route_with_valid_session_is_forwarded_test() {
  let #(response, sent) =
    run(
      testing.put("/recipes/pancakes", [#("cookie", "session=abc")], "{}"),
      identity_and_upstream("{\"valid\":true}"),
    )

  response.status |> should.equal(200)
  let assert [validation, upstream] = sent
  validation.host |> should.equal("identity.test")
  validation.path |> should.equal("/api/v1/validate-token")
  request.get_header(validation, "cookie") |> should.equal(Ok("session=abc"))
  upstream.method |> should.equal(http.Put)
  upstream.path |> should.equal("/api/v1/pancakes")
}

pub fn cookie_route_with_invalid_session_is_unauthorized_test() {
  let #(response, sent) =
    run(
      testing.put("/recipes/pancakes", [#("cookie", "session=stale")], "{}"),
      identity_and_upstream("{\"valid\":false}"),
    )

  response.status |> should.equal(401)
  let assert [validation] = sent
  validation.host |> should.equal("identity.test")
}

pub fn nested_cookie_route_requires_session_test() {
  let #(response, _) =
    run(
      testing.delete("/recipes/ingredients/flour", [], ""),
      identity_and_upstream("{\"valid\":false}"),
    )

  response.status |> should.equal(401)
}

pub fn bearer_route_with_matching_audience_is_forwarded_test() {
  let #(response, sent) =
    run(
      testing.post(
        "/agents/runs",
        [#("authorization", "Bearer caller-token")],
        "{}",
      ),
      identity_and_upstream(
        "{\"active\":true,\"aud\":\"agents\",\"client_name\":\"ci\"}",
      ),
    )

  response.status |> should.equal(200)
  let assert [introspection, upstream] = sent
  introspection.method |> should.equal(http.Post)
  introspection.path |> should.equal("/api/v1/oauth/introspect")
  introspection.body |> should.equal("{\"token\":\"caller-token\"}")
  upstream.host |> should.equal("agents.test")
  upstream.path |> should.equal("/runs")
  request.get_header(upstream, "x-nrdrm-client") |> should.equal(Ok("ci"))
  request.get_header(upstream, "authorization") |> should.equal(Error(Nil))
}

pub fn bearer_route_overrides_caller_supplied_client_name_test() {
  let #(_, sent) =
    run(
      testing.post(
        "/agents/runs",
        [
          #("authorization", "Bearer caller-token"),
          #("x-nrdrm-client", "spoofed"),
        ],
        "{}",
      ),
      identity_and_upstream(
        "{\"active\":true,\"aud\":\"agents\",\"client_name\":\"ci\"}",
      ),
    )

  let assert [_, upstream] = sent
  request.get_header(upstream, "x-nrdrm-client") |> should.equal(Ok("ci"))
}

pub fn bearer_route_without_token_is_unauthorized_test() {
  let #(response, sent) =
    run(testing.post("/agents/runs", [], "{}"), identity_and_upstream("{}"))

  response.status |> should.equal(401)
  sent |> should.equal([])
}

pub fn bearer_route_with_inactive_token_is_unauthorized_test() {
  let #(response, sent) =
    run(
      testing.get("/agents/runs/42", [#("authorization", "Bearer revoked")]),
      identity_and_upstream("{\"active\":false}"),
    )

  response.status |> should.equal(401)
  let assert [introspection] = sent
  introspection.host |> should.equal("identity.test")
}

pub fn bearer_route_for_another_audience_is_unauthorized_test() {
  let #(response, sent) =
    run(
      testing.post(
        "/agents/complete",
        [#("authorization", "Bearer recipes-token")],
        "{}",
      ),
      identity_and_upstream("{\"active\":true,\"aud\":\"recipes\"}"),
    )

  response.status |> should.equal(401)
  let assert [introspection] = sent
  introspection.host |> should.equal("identity.test")
}

pub fn unprotected_agents_route_skips_introspection_test() {
  let #(response, sent) =
    run(
      testing.post("/agents/webhooks/github", [], "{}"),
      identity_and_upstream("{}"),
    )

  response.status |> should.equal(200)
  let assert [upstream] = sent
  upstream.host |> should.equal("agents.test")
  string.starts_with(upstream.path, "/webhooks/github") |> should.be_true
}
