import app/request_id
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

pub fn livez_answers_without_calling_upstreams_test() {
  let #(response, sent) =
    run(testing.get("/_gateway/livez", []), fn(_) { fixture.json(200, "{}") })

  response.status |> should.equal(200)
  testing.string_body(response) |> should.equal("{\"status\":\"ok\"}")
  sent |> should.equal([])
}

pub fn status_reports_gateway_and_every_upstream_test() {
  let #(response, sent) =
    run(
      testing.get("/_gateway/status", [#("x-request-id", "probe-1")]),
      fn(req) {
        case req.host {
          "agents.test" -> fixture.json(200, "{\"status\":\"ok\"}")
          _ ->
            fixture.json(200, "{\"boot_time\":\"t0\",\"api_version\":\"v1\"}")
        }
      },
    )

  response.status |> should.equal(200)
  let body = testing.string_body(response)
  string.contains(
    body,
    "\"gateway\":{\"boot_time\":\"2026-01-01T00:00:00Z\",\"api_version\":\"test\"}",
  )
  |> should.be_true
  string.contains(body, "\"recipes\":{\"up\":true,\"status\":200,")
  |> should.be_true
  string.contains(body, "\"boot_time\":\"t0\",\"api_version\":\"v1\"}")
  |> should.be_true
  string.contains(body, "\"agents\":{\"up\":true,\"status\":200,")
  |> should.be_true

  list.map(sent, fn(req) { #(req.host, req.path) })
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  |> should.equal([
    #("agents.test", "/health"),
    #("identity.test", "/api/v1/health"),
    #("recipes.test", "/api/v1/health"),
  ])
  list.each(sent, fn(req) {
    request.get_header(req, "x-request-id") |> should.equal(Ok("probe-1"))
  })
}

pub fn status_still_answers_when_upstreams_are_down_test() {
  let #(response, _) =
    run(testing.get("/_gateway/status", []), fn(_) {
      Error(transport.FailedToConnect("econnrefused"))
    })

  response.status |> should.equal(200)
  string.contains(
    testing.string_body(response),
    "\"recipes\":{\"up\":false,\"status\":null,",
  )
  |> should.be_true
}

pub fn health_is_gone_test() {
  let #(response, sent) =
    run(testing.get("/health", []), fn(_) { fixture.json(200, "{}") })

  response.status |> should.equal(404)
  sent |> should.equal([])
}

pub fn unknown_gateway_endpoint_is_not_found_test() {
  let #(response, sent) =
    run(testing.get("/_gateway/readyz", []), fn(_) { fixture.json(200, "{}") })

  response.status |> should.equal(404)
  sent |> should.equal([])
}

pub fn valid_request_id_is_kept_echoed_and_forwarded_test() {
  let #(response, sent) =
    run(
      testing.get("/recipes/pancakes", [#("x-request-id", "Abc-1.2_3")]),
      fn(_) { fixture.json(200, "{}") },
    )

  response.get_header(response, "x-request-id") |> should.equal(Ok("Abc-1.2_3"))
  let assert [upstream] = sent
  request.get_header(upstream, "x-request-id") |> should.equal(Ok("Abc-1.2_3"))
}

pub fn unsafe_request_id_is_replaced_test() {
  let too_long = string.repeat("a", 65)
  list.each(["", "has space", "line\nbreak", "{\"json\":1}", too_long], fn(id) {
    let #(response, sent) =
      run(testing.get("/recipes/pancakes", [#("x-request-id", id)]), fn(_) {
        fixture.json(200, "{}")
      })

    let assert Ok(echoed) = response.get_header(response, "x-request-id")
    echoed |> should.not_equal(id)
    request_id.is_valid(echoed) |> should.be_true
    let assert [upstream] = sent
    request.get_header(upstream, "x-request-id") |> should.equal(Ok(echoed))
  })
}

pub fn missing_request_id_is_generated_per_request_test() {
  let #(first, _) =
    run(testing.get("/recipes/pancakes", []), fn(_) { fixture.json(200, "{}") })
  let #(second, _) =
    run(testing.get("/recipes/pancakes", []), fn(_) { fixture.json(200, "{}") })

  let assert Ok(first_id) = response.get_header(first, "x-request-id")
  let assert Ok(second_id) = response.get_header(second, "x-request-id")
  request_id.is_valid(first_id) |> should.be_true
  first_id |> should.not_equal(second_id)
}

pub fn request_id_is_echoed_on_every_kind_of_response_test() {
  let id = [#("x-request-id", "edge-1")]
  let echoed = fn(response: wisp.Response) {
    response.get_header(response, "x-request-id") |> should.equal(Ok("edge-1"))
  }

  let #(unauthorized, _) =
    run(testing.post("/agents/runs", id, "{}"), identity_and_upstream("{}"))
  unauthorized.status |> should.equal(401)
  echoed(unauthorized)

  let #(not_found, _) =
    run(testing.get("/nope", id), fn(_) { fixture.json(200, "{}") })
  not_found.status |> should.equal(404)
  echoed(not_found)

  let #(bad_gateway, _) =
    run(testing.get("/recipes/pancakes", id), fn(_) {
      Error(transport.FailedToConnect("econnrefused"))
    })
  bad_gateway.status |> should.equal(502)
  echoed(bad_gateway)

  let #(gateway_timeout, _) =
    run(testing.get("/recipes/pancakes", id), fn(_) { Error(transport.Timeout) })
  gateway_timeout.status |> should.equal(504)
  echoed(gateway_timeout)

  let #(crashed, _) =
    run(testing.get("/recipes/pancakes", id), fn(_) { panic as "boom" })
  crashed.status |> should.equal(500)
  echoed(crashed)

  let #(preflight, sent) =
    run(
      testing.request(
        http.Options,
        "/recipes/pancakes",
        [
          #("origin", "http://localhost:3000"),
          #("access-control-request-method", "PUT"),
          ..id
        ],
        <<>>,
      ),
      fn(_) { fixture.json(200, "{}") },
    )
  echoed(preflight)
  sent |> should.equal([])
}

pub fn request_id_reaches_identity_calls_test() {
  let id = #("x-request-id", "auth-1")

  let #(_, sent) =
    run(
      testing.put("/recipes/pancakes", [#("cookie", "session=abc"), id], "{}"),
      identity_and_upstream("{\"valid\":true}"),
    )
  let assert [validation, _] = sent
  request.get_header(validation, "x-request-id") |> should.equal(Ok("auth-1"))

  let #(_, sent) =
    run(
      testing.post(
        "/agents/runs",
        [#("authorization", "Bearer token"), id],
        "{}",
      ),
      identity_and_upstream("{\"active\":true,\"aud\":\"agents\"}"),
    )
  let assert [introspection, upstream] = sent
  request.get_header(introspection, "x-request-id")
  |> should.equal(Ok("auth-1"))
  request.get_header(upstream, "x-request-id") |> should.equal(Ok("auth-1"))
}

pub fn unknown_service_is_not_found_test() {
  let #(response, sent) =
    run(testing.get("/nope/anything", []), fn(_) { fixture.json(200, "{}") })

  response.status |> should.equal(404)
  sent |> should.equal([])
}

pub fn request_matching_no_rule_is_not_found_test() {
  let #(response, sent) =
    run(testing.get("/agents/unlisted", []), fn(_) { fixture.json(200, "{}") })

  response.status |> should.equal(404)
  sent |> should.equal([])
}

pub fn listed_path_with_unlisted_method_is_not_found_test() {
  let #(response, sent) =
    run(testing.get("/agents/webhooks/github", []), fn(_) {
      fixture.json(200, "{}")
    })

  response.status |> should.equal(404)
  sent |> should.equal([])
}

pub fn each_upstream_is_called_with_its_own_timeout_test() {
  let calls = process.new_subject()
  let ctx =
    fixture.context(fn(req: Request(BitArray), timeout_ms) {
      process.send(calls, #(req.host, timeout_ms))
      case req.host {
        "identity.test" ->
          fixture.json(200, "{\"active\":true,\"aud\":\"agents\"}")
        _ -> fixture.json(200, "{}")
      }
    })

  router.handle_request(testing.get("/recipes/pancakes", []), ctx)
  router.handle_request(
    testing.get("/agents/runs/42", [#("authorization", "Bearer token")]),
    ctx,
  )

  [
    process.receive(calls, 0),
    process.receive(calls, 0),
    process.receive(calls, 0),
  ]
  |> should.equal([
    Ok(#("recipes.test", 30_000)),
    Ok(#("identity.test", 10_000)),
    Ok(#("agents.test", 120_000)),
  ])
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

pub fn refreshed_session_cookie_is_returned_to_the_caller_test() {
  let #(response, sent) =
    run(
      testing.put("/recipes/pancakes", [#("cookie", "session=expired")], "{}"),
      fn(req) {
        case req.host {
          "identity.test" ->
            Ok(
              response.new(200)
              |> response.set_header("content-type", "application/json")
              |> response.set_header("set-cookie", "nrdrm-login=refreshed")
              |> response.set_body(<<"{\"valid\":true}":utf8>>),
            )
          _ ->
            Ok(
              response.new(200)
              |> response.set_header("set-cookie", "other=1; Path=/app")
              |> response.set_body(<<"{}":utf8>>),
            )
        }
      },
    )

  response.status |> should.equal(200)
  set_cookies(response)
  |> should.equal(["nrdrm-login=refreshed; Path=/", "other=1; Path=/app"])
  let assert [_, upstream] = sent
  request.get_header(upstream, "cookie") |> should.equal(Ok("session=expired"))
  request.get_header(upstream, "set-cookie") |> should.equal(Error(Nil))
}

pub fn cleared_session_cookie_is_returned_on_unauthorized_test() {
  let #(response, sent) =
    run(
      testing.put("/recipes/pancakes", [#("cookie", "session=withdrawn")], "{}"),
      fn(req) {
        case req.host {
          "identity.test" ->
            Ok(
              response.new(200)
              |> response.set_header("content-type", "application/json")
              |> response.set_header(
                "set-cookie",
                "nrdrm-login=; Max-Age=0; Path=/",
              )
              |> response.set_body(<<"{\"valid\":false}":utf8>>),
            )
          _ -> fixture.json(200, "{}")
        }
      },
    )

  response.status |> should.equal(401)
  set_cookies(response)
  |> should.equal(["nrdrm-login=; Max-Age=0; Path=/"])
  let assert [validation] = sent
  validation.host |> should.equal("identity.test")
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
