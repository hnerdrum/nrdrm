import app/context.{type Context}
import app/identity.{type Introspection}
import app/route.{type Match}
import config/path_pattern
import config/routing.{type Rule, Bearer, Public, Rule, Session}
import gleam/http.{type Method}
import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import wisp.{type Request}

pub fn auth_middleware(
  req: wisp.Request,
  ctx: Context,
  match: Match,
  handler: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case matching_rule(match, req.method) {
    Error(Nil) -> {
      wisp.log_warning(
        "No rule found for "
        <> http.method_to_string(req.method)
        <> " "
        <> req.path,
      )
      wisp.not_found()
    }
    Ok(Rule(auth: Public, ..)) -> handler(req)
    Ok(Rule(auth: Session, ..)) ->
      case identity.validate_session(ctx.transport, ctx.routing.identity, req) {
        True -> handler(req)
        False -> unauthorized()
      }
    Ok(Rule(auth: Bearer(audience), ..)) ->
      case identity.introspect(ctx.transport, ctx.routing.identity, req) {
        Ok(introspection) ->
          case bearer_permitted(introspection, audience) {
            True -> handler(attach_client(req, introspection.client_name))
            False -> unauthorized()
          }
        Error(_) -> unauthorized()
      }
  }
}

pub fn matching_rule(match: Match, method: Method) -> Result(Rule, Nil) {
  list.find(match.route.rules, fn(rule) {
    path_pattern.matches(rule.path, match.path)
    && list.contains(rule.methods, method)
  })
}

pub fn bearer_permitted(
  introspection: Introspection,
  audience: String,
) -> Bool {
  introspection.active && introspection.audience == Some(audience)
}

/// `x-nrdrm-*` headers carry identity the gateway vouches for, so callers
/// must never be able to supply them.
pub fn strip_reserved_headers(req: Request) -> Request {
  let headers =
    list.filter(req.headers, fn(header) {
      !string.starts_with(string.lowercase(header.0), "x-nrdrm-")
    })
  request.Request(..req, headers: headers)
}

pub fn attach_client(req: Request, client_name: Option(String)) -> Request {
  case client_name {
    Some(name) -> request.set_header(req, "x-nrdrm-client", name)
    None -> req
  }
}

fn unauthorized() -> wisp.Response {
  wisp.string_body(wisp.response(401), "Unauthorized")
}
