import app/context.{type Context}
import app/forward.{forward_request}
import app/health.{HealthCheck}
import app/middleware.{auth_middleware}
import app/route
import app/web
import config/routing.{type Upstream}
import gleam/bit_array
import gleam/json
import gleam/list
import gleam/result
import gleam/string_tree
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  case wisp.path_segments(req) {
    ["health"] -> {
      let upstream_results =
        list.map(ctx.routing.upstreams, fn(upstream) {
          #(upstream.name, upstream_health(ctx, upstream))
        })

      let data =
        json.object([
          #(
            "gateway",
            health.to_json(HealthCheck(
              ctx.config.boot_time,
              ctx.config.api_version,
            )),
          ),
          ..upstream_results
        ])

      wisp.json_response(string_tree.from_string(json.to_string(data)), 200)
    }

    segments ->
      case route.resolve(ctx.routing.routes, segments) {
        Ok(match) -> {
          use req <- auth_middleware(req, ctx, match)
          forward_request(ctx.transport, match, req)
        }
        Error(_) -> {
          wisp.log_warning("No route found for request path: " <> req.path)
          wisp.not_found()
        }
      }
  }
}

fn upstream_health(ctx: Context, upstream: Upstream) -> json.Json {
  let req = routing.upstream_request(upstream, ["health"])
  {
    use response <- result.try(
      ctx.transport(req, upstream.timeout_ms)
      |> result.replace_error("Upstream unreachable"),
    )
    use body <- result.try(
      bit_array.to_string(response.body)
      |> result.replace_error("Invalid UTF-8 binary data"),
    )
    health.from_json_string(body)
  }
  |> result.map(health.to_json)
  |> result.unwrap(
    json.object([#("error", json.string("Failed to parse health response"))]),
  )
}
