import gleam/list
import gleam/string
import gleam/string_tree
import wisp.{type Request, type Response}
import app/context.{type Context}
import config/service
import app/forward.{forward_request}
import app/web
import app/health.{HealthCheck}
import gleam/json
import gleam/result

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use _req <- web.middleware(req, ctx)

  let services = ctx.services

  case wisp.path_segments(req) {
    ["health"] -> {
      let service_results = list.map(services, fn(service) {
        let response = forward_request(service, "health", req)

        let health_json = {
          use body_string <- result.try(forward.parse_string_response(response))
          use health_check <- result.try(health.from_json_string(body_string))
          Ok(health.to_json(health_check))
        } |> result.unwrap(json.object([
          #("error", json.string("Failed to parse health response"))
        ]))

        #(service.name, health_json)
      })

      let data = json.object([
        #("gateway", health.to_json(HealthCheck(ctx.config.boot_time, ctx.config.api_version))),
        ..service_results
      ])

      wisp.json_response(string_tree.from_string(json.to_string(data)), 200)
    }

    [service_name, ..path_segments] -> {
      case service.find(services, service_name) {
        Ok(service) -> {
          forward_request(service, string.join(path_segments, "/"), req)
        }
        Error(_) -> {
          wisp.log_warning("No service found for request path: " <> req.path)
          wisp.not_found()
        }
      }
    }

    _ -> wisp.not_found()
  }
}
