import gleam/list
import gleam/string
import wisp.{type Request, type Response}
import app/context.{type Context}
import config/service
import app/forward.{forward_request}
import app/web

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use _req <- web.middleware(req, ctx)

  let services = ctx.services

  case wisp.path_segments(req) {
    ["health"] -> {
      list.each(services, fn(service) { forward_request(service, "health", req) })
      wisp.ok()
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
