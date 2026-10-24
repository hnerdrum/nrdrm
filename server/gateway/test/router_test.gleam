import app/router
import app/transport
import fixture
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import wisp
import wisp/testing

fn run(
  req: wisp.Request,
  respond: fixture.Responder,
) -> #(wisp.Response, List(Request(BitArray))) {
  let sent = process.new_subject()
  let ctx = fixture.context(fixture.recording_transport(sent, respond))
  let response = router.handle_request(req, ctx)
  #(response, fixture.sent_requests(sent))
}

fn identity_and_upstream(identity_body: String) -> fixture.Responder {
  fn(req: Request(BitArray)) {
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

pub fn query_string_is_forwarded_test() {
  let #(_, sent) =
    run(testing.get("/recipes/search?q=pancakes&limit=5", []), fn(_) {
      fixture.json(200, "[]")
    })

  let assert [upstream] = sent
  upstream.path |> should.equal("/api/v1/search")
  upstream.query |> should.equal(Some("q=pancakes&limit=5"))
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
  upstream.body |> should.equal(<<"{\"action\":\"opened\"}":utf8>>)
  request.get_header(upstream, "content-type")
  |> should.equal(Ok("application/json"))
}

pub fn binary_bodies_pass_through_unchanged_test() {
  let image = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00>>
  let #(response, sent) =
    run(
      testing.request(
        http.Post,
        "/recipes/images",
        [#("content-type", "image/jpeg")],
        image,
      ),
      fn(_) {
        Ok(
          response.new(200)
          |> response.set_header("content-type", "image/jpeg")
          |> response.set_body(image),
        )
      },
    )

  response.status |> should.equal(200)
  testing.bit_array_body(response) |> should.equal(image)
  let assert [upstream] = sent
  upstream.body |> should.equal(image)
}

pub fn upstream_status_and_content_type_are_preserved_test() {
  let #(response, _) =
    run(testing.get("/recipes/export", []), fn(_) {
      Ok(
        response.new(201)
        |> response.set_header("content-type", "text/csv")
        |> response.set_body(<<"name\npancakes\n":utf8>>),
      )
    })

  response.status |> should.equal(201)
  response.get_header(response, "content-type") |> should.equal(Ok("text/csv"))
  testing.string_body(response) |> should.equal("name\npancakes\n")
}

fn set_cookies(response: wisp.Response) -> List(String) {
  list.filter_map(response.headers, fn(header) {
    case header.0 {
      "set-cookie" -> Ok(header.1)
      _ -> Error(Nil)
    }
  })
  |> list.sort(string.compare)
}

pub fn every_upstream_set_cookie_is_returned_test() {
  let #(response, _) =
    run(testing.post("/identity/login", [], "{}"), fn(_) {
      Ok(
        response.new(200)
        |> response.prepend_header("set-cookie", "access=a; Path=/")
        |> response.prepend_header("set-cookie", "refresh=r; Path=/")
        |> response.set_body(<<"{}":utf8>>),
      )
    })

  set_cookies(response)
  |> should.equal(["access=a; Path=/", "refresh=r; Path=/"])
}

pub fn set_cookie_without_path_defaults_to_root_test() {
  let #(response, _) =
    run(testing.post("/identity/login", [], "{}"), fn(_) {
      Ok(
        response.new(200)
        |> response.prepend_header("set-cookie", "access=a; HttpOnly")
        |> response.prepend_header("set-cookie", "scoped=s; path=/api")
        |> response.set_body(<<"{}":utf8>>),
      )
    })

  set_cookies(response)
  |> should.equal(["access=a; HttpOnly; Path=/", "scoped=s; path=/api"])
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

pub fn health_reports_gateway_and_every_service_test() {
  let #(response, _) =
    run(testing.get("/health", []), fn(_) {
      fixture.json(200, "{\"boot_time\":\"t0\",\"api_version\":\"abc1234\"}")
    })

  response.status |> should.equal(200)
  let body = testing.string_body(response)
  string.contains(body, "\"gateway\":{\"boot_time\":\"2026-01-01T00:00:00Z\"")
  |> should.be_true
  string.contains(
    body,
    "\"recipes\":{\"boot_time\":\"t0\",\"api_version\":\"abc1234\"}",
  )
  |> should.be_true
  string.contains(body, "\"agents\":{\"boot_time\":\"t0\"") |> should.be_true
}

pub fn unknown_service_is_not_found_test() {
  let #(response, sent) =
    run(testing.get("/nope/anything", []), fn(_) { fixture.json(200, "{}") })

  response.status |> should.equal(404)
  sent |> should.equal([])
}

pub fn upstream_connection_failure_is_bad_gateway_test() {
  let #(response, _) =
    run(testing.get("/recipes/pancakes", []), fn(_) {
      Error(transport.FailedToConnect("econnrefused"))
    })

  response.status |> should.equal(502)
}

pub fn upstream_timeout_is_gateway_timeout_test() {
  let #(response, _) =
    run(testing.get("/recipes/pancakes", []), fn(_) { Error(transport.Timeout) })

  response.status |> should.equal(504)
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
  introspection.body |> should.equal(<<"{\"token\":\"caller-token\"}":utf8>>)
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

pub fn caller_cannot_spoof_client_name_on_unprotected_route_test() {
  let #(_, sent) =
    run(
      testing.post(
        "/agents/webhooks/github",
        [#("x-nrdrm-client", "spoofed")],
        "{}",
      ),
      identity_and_upstream("{}"),
    )

  let assert [upstream] = sent
  request.get_header(upstream, "x-nrdrm-client") |> should.equal(Error(Nil))
}

pub fn bearer_scheme_is_case_and_whitespace_insensitive_test() {
  let #(_, sent) =
    run(
      testing.post(
        "/agents/runs",
        [#("authorization", "  bearer   caller-token ")],
        "{}",
      ),
      identity_and_upstream("{\"active\":false}"),
    )

  let assert [introspection] = sent
  introspection.body |> should.equal(<<"{\"token\":\"caller-token\"}":utf8>>)
}

pub fn non_bearer_authorization_is_unauthorized_test() {
  let #(response, sent) =
    run(
      testing.post("/agents/runs", [#("authorization", "Basic abc")], "{}"),
      identity_and_upstream("{}"),
    )

  response.status |> should.equal(401)
  sent |> should.equal([])
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
