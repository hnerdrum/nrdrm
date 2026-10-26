import app/context.{type Context}
import app/forward.{forward_request}
import app/middleware.{auth_middleware}
import app/route.{type Match}
import app/status
import app/web
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleam/string_tree
import wisp.{type Request, type Response}

const status_timeout_ms = 2000

type Target {
  Livez
  Status
  Proxy(Match)
  Unrouted
}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  let target = case wisp.path_segments(req) {
    ["_gateway", "livez"] -> Livez
    ["_gateway", "status"] -> Status
    segments ->
      case route.resolve(ctx.routing.routes, segments) {
        Ok(match) -> Proxy(match)
        Error(Nil) -> Unrouted
      }
  }
  let route = case target {
    Proxy(match) -> Some(match.route)
    Livez | Status | Unrouted -> None
  }

  use req <- web.middleware(req, ctx, route)

  case target {
    Livez -> {
      use <- wisp.require_method(req, http.Get)
      json_response(json.object([#("status", json.string("ok"))]))
    }
    Status -> {
      use <- wisp.require_method(req, http.Get)
      status.check_all(
        ctx.transport,
        ctx.routing.upstreams,
        req,
        status_timeout_ms,
      )
      |> status.to_json(ctx.config, _)
      |> json_response
    }
    Proxy(match) -> {
      use req <- auth_middleware(req, ctx, match)
      forward_request(ctx.transport, match, req)
    }
    Unrouted -> {
      wisp.log_warning("No route found for request path: " <> req.path)
      wisp.not_found()
    }
  }
}

fn json_response(data: json.Json) -> Response {
  wisp.json_response(string_tree.from_string(json.to_string(data)), 200)
}
