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

    [service_name] -> {
      case find_service(services, service_name) {
        Ok(service) -> handle_service_request(service, req)
        Error(_) -> wisp.not_found()
      }
    }

    _ -> wisp.not_found()
  }
}

fn find_service(services: List(ServiceConfig), name: String) -> Result(ServiceConfig, Nil) {
  list.find(services, fn(service) { service.name == name })
}

fn handle_service_request(service: ServiceConfig, req: Request) -> Response {
  let url = find_service_url(service, req)
  forward_request(url)
}

// TODO: fix how we do this
fn find_service_url(service: ServiceConfig, req: Request) -> String {
  let path = string.slice(req.path, 1, string.length(req.path))
  service.base_url <> "/" <> string.slice(path, string.length(service.name), string.length(path))
}

fn forward_request(url: String) -> Response {
  case request.to(url) {
    Ok(res) -> forward(res)
    Error(_) -> wisp.internal_server_error()
  }

}

fn forward(request: request.Request(String)) -> Response {
  case hackney.send(request) {
    Ok(response) -> wisp.json_response(string_builder.from_string(response.body), response.status)
    Error(_) -> wisp.internal_server_error()
  }
}