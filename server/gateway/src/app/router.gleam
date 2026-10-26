import app/context.{type Context}
import app/forward.{forward_request}
import app/health.{HealthCheck}
import app/middleware.{auth_middleware}
import app/route
import app/web
import gleam/json
import gleam/list
import gleam/result
import gleam/string_tree
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  let services = ctx.services

  case wisp.path_segments(req) {
    ["health"] -> {
      let service_results =
        list.map(services, fn(service) {
          let response =
            forward_request(ctx.transport, service, ["health"], req)

          let health_json =
            {
              use body_string <- result.try(forward.parse_string_response(
                response,
              ))
              use health_check <- result.try(health.from_json_string(
                body_string,
              ))
              Ok(health.to_json(health_check))
            }
            |> result.unwrap(
              json.object([
                #("error", json.string("Failed to parse health response")),
              ]),
            )

          #(service.name, health_json)
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
          ..service_results
        ])

      wisp.json_response(string_tree.from_string(json.to_string(data)), 200)
    }

    segments ->
      case route.resolve(services, segments) {
        Ok(match) -> {
          use req <- auth_middleware(req, ctx, match)
          forward_request(ctx.transport, match.service, match.path, req)
        }
        Error(_) -> {
          wisp.log_warning("No service found for request path: " <> req.path)
          wisp.not_found()
        }
      }
  }
}
