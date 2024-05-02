import gleam/hackney
import gleam/http/request
import gleam/list
import gleam/string
import gleam/string_builder
import wisp.{type Request, type Response}
import app/web
import config/services.{type ServiceConfig}

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  let services = services.load_service_config()

  case wisp.path_segments(req) {
    ["health"] -> wisp.ok()

    [service_name, ..path_segments] -> {
      case find_service(services, service_name) {
        Ok(service) -> forward_request(services.create_url(service, string.join(path_segments, "/")))
        Error(_) -> {
          wisp.log_warning("No service found for request path: " <> req.path)
          wisp.not_found()
        }
      }
    }

    _ -> wisp.not_found()
  }
}

fn find_service(services: List(ServiceConfig), name: String) -> Result(ServiceConfig, Nil) {
  list.find(services, fn(service) { service.name == name })
}

fn forward_request(url: String) -> Response {
  wisp.log_info("Forwarding request to URL: " <> url)

  case request.to(url) {
    Ok(req) -> send(req)
    Error(_) -> {
      wisp.log_error("Server error when trying to create a request to: " <> url)
      wisp.internal_server_error()
    }
  }

}

fn send(request: request.Request(String)) -> Response {
  case hackney.send(request) {
    Ok(response) -> wisp.json_response(string_builder.from_string(response.body), response.status)
    Error(_) -> {
      let url = request.host <> request.path
      wisp.log_error("Server error when trying to send a request to: " <> url)
      wisp.internal_server_error()
    }
  }
}