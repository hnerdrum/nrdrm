import app/forward
import app/middleware
import config/env.{Dev}
import config/service
import gleam/http/request
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should

pub fn cookie_rules_use_validate_token_test() {
  let assert Ok(services) = service.load_services(Dev, "hop-secret")
  let assert Ok(recipes) = service.find(services, "recipes")

  middleware.required_scheme(recipes, "pancakes", "PUT")
  |> should.equal(Ok(service.Cookie))
  middleware.identity_path(service.Cookie)
  |> should.equal("validate-token")
}

pub fn inactive_bearer_is_rejected_test() {
  middleware.bearer_permitted(
    middleware.Introspection(False, None, None),
    "agents",
  )
  |> should.equal(False)
}

pub fn active_agents_bearer_is_forwarded_test() {
  middleware.bearer_permitted(
    middleware.Introspection(True, Some("agents"), Some("agents-caller")),
    "agents",
  )
  |> should.equal(True)
}

pub fn active_bearer_for_another_audience_is_rejected_test() {
  middleware.bearer_permitted(
    middleware.Introspection(True, Some("recipes"), Some("agents-caller")),
    "agents",
  )
  |> should.equal(False)
}

pub fn github_webhook_is_not_introspected_test() {
  let assert Ok(services) = service.load_services(Dev, "hop-secret")
  let assert Ok(agents) = service.find(services, "agents")

  middleware.required_scheme(agents, "webhooks/github", "POST")
  |> should.equal(Error(Nil))
  middleware.required_scheme(agents, "runs", "POST")
  |> should.equal(Ok(service.Bearer("agents")))
  middleware.identity_path(service.Bearer("agents"))
  |> should.equal("oauth/introspect")
}

pub fn hop_secret_replaces_caller_authorization_test() {
  let assert Ok(services) = service.load_services(Dev, "hop-secret")
  let assert Ok(agents) = service.find(services, "agents")
  let assert Ok(req) = request.to("http://localhost:8090/runs")
  let req = request.set_header(req, "authorization", "Bearer caller-token")

  let forwarded = forward.set_hop_authorization(req, agents)

  request.get_header(forwarded, "authorization")
  |> should.equal(Ok("Bearer hop-secret"))
  list.contains(agents.request.forward_headers, "authorization")
  |> should.equal(False)
}
