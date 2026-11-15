import app/context.{type Context}
import app/identity.{type Introspection, IdentityUnavailable, NoBearerToken}
import app/request_id
import app/route.{type Match}
import config/path_pattern
import config/routing.{type Rule, Bearer, Public, Rule, Session}
import gleam/http.{type Method}
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import wisp.{type Request, type Response}

pub fn auth_middleware(
  req: wisp.Request,
  ctx: Context,
  match: Match,
  handler: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case matching_rule(match, req.method) {
    Error(Nil) ->
      case disallowed_mcp_method(match) {
        Ok(allowed) -> wisp.method_not_allowed(allowed)
        Error(Nil) -> {
          wisp.log_warning(
            "No rule found for "
            <> http.method_to_string(req.method)
            <> " "
            <> req.path,
          )
          wisp.not_found()
        }
      }
    Ok(Rule(auth: Public, ..)) -> handler(req)
    Ok(Rule(auth: Session, ..)) -> {
      let session =
        identity.validate_session(ctx.transport, ctx.routing.identity, req)
      let response = case session.valid {
        True -> handler(req)
        False -> unauthorized()
      }
      with_set_cookies(response, session.set_cookies)
    }
    Ok(Rule(auth: Bearer(audience, scope), ..)) ->
      case identity.introspect(ctx.transport, ctx.routing.identity, req) {
        Error(NoBearerToken) -> bearer_rejected(audience, scope)
        Error(IdentityUnavailable) -> identity_unavailable(scope)
        Ok(introspection) ->
          case bearer_permitted(introspection, audience, scope) {
            True -> handler(attach_bearer(req, introspection, scope))
            False -> bearer_rejected(audience, scope)
          }
      }
  }
}

/// Another method on a scoped bearer path, such as the MCP endpoint, is 405.
fn disallowed_mcp_method(match: Match) -> Result(List(Method), Nil) {
  let rules =
    list.filter(match.route.rules, fn(rule) {
      path_pattern.matches(rule.path, match.path)
    })
  let mcp_path =
    rules != []
    && list.all(rules, fn(rule) {
      case rule.auth {
        Bearer(_, Some(_)) -> True
        _ -> False
      }
    })
  case mcp_path {
    True -> Ok(list.flat_map(rules, fn(rule) { rule.methods }))
    False -> Error(Nil)
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
  scope: Option(String),
) -> Bool {
  let audience_ok =
    introspection.active && introspection.audience == Some(audience)
  case scope {
    None -> audience_ok
    Some(required) ->
      audience_ok
      && scope_includes(introspection.scope, required)
      && email_of(introspection) != None
  }
}

fn scope_includes(scope: Option(String), required: String) -> Bool {
  case scope {
    None -> False
    Some(scope) ->
      string.split(scope, " ")
      |> list.map(string.trim)
      |> list.contains(required)
  }
}

fn email_of(introspection: Introspection) -> Option(String) {
  case introspection.email {
    Some(email) ->
      case string.trim(email) {
        "" -> None
        email -> Some(email)
      }
    None -> None
  }
}

/// `x-nrdrm-*` headers carry identity the gateway vouches for, so callers
/// must never be able to supply them.
pub fn strip_reserved_headers(req: Request) -> Request {
  let headers =
    list.filter(req.headers, fn(header) {
      !is_reserved_header(string.lowercase(header.0))
    })
  request.Request(..req, headers: headers)
}

pub fn is_gateway_header(name: String) -> Bool {
  name == request_id.header || is_reserved_header(name)
}

fn is_reserved_header(name: String) -> Bool {
  string.starts_with(name, "x-nrdrm-")
}

pub fn attach_client(req: Request, client_name: Option(String)) -> Request {
  case client_name {
    Some(name) -> request.set_header(req, "x-nrdrm-client", name)
    None -> req
  }
}

fn attach_bearer(
  req: Request,
  introspection: Introspection,
  scope: Option(String),
) -> Request {
  case scope {
    None -> attach_client(req, introspection.client_name)
    Some(_) ->
      case email_of(introspection) {
        Some(email) -> request.set_header(req, "x-nrdrm-email", email)
        None -> req
      }
  }
}

fn bearer_rejected(audience: String, scope: Option(String)) -> Response {
  case scope {
    None -> unauthorized()
    Some(scope) ->
      unauthorized()
      |> response.set_header("www-authenticate", challenge(audience, scope))
  }
}

fn challenge(resource_url: String, scope: String) -> String {
  "Bearer resource_metadata=\""
  <> metadata_url(resource_url)
  <> "\", scope=\""
  <> scope
  <> "\""
}

fn metadata_url(resource_url: String) -> String {
  string.drop_end(resource_url, 4) <> "/oauth-protected-resource"
}

fn identity_unavailable(scope: Option(String)) -> Response {
  case scope {
    None -> unauthorized()
    Some(_) -> wisp.string_body(wisp.response(503), "Unavailable")
  }
}

fn unauthorized() -> wisp.Response {
  wisp.string_body(wisp.response(401), "Unauthorized")
}

pub fn with_set_cookies(response: Response, cookies: List(String)) -> Response {
  list.fold_right(cookies, response, fn(acc, cookie) {
    response.prepend_header(acc, "set-cookie", ensure_cookie_path(cookie))
  })
}

pub fn ensure_cookie_path(cookie: String) -> String {
  let has_path =
    string.split(cookie, ";")
    |> list.any(fn(attribute) {
      string.trim(attribute) |> string.lowercase |> string.starts_with("path=")
    })
  case has_path {
    True -> cookie
    False -> cookie <> "; Path=/"
  }
}
