import gleam/http/request
import gleam/httpc
import gleam/list
import gleam/string
import gleam/string_builder
import wisp.{type Request, type Response}
import app/web.{type Context}
import config/service.{type Service}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use _req <- web.middleware(req, ctx)

  let services = ctx.services

  case wisp.path_segments(req) {
    ["health"] -> {
      list.each(services, fn(service) { forward_request(service.create_url(service, "health"), req) })
      wisp.ok()
    }

    [service_name, ..path_segments] -> {
      case find_service(services, service_name) {
        Ok(service) -> forward_request(service.create_url(service, string.join(path_segments, "/")), req)
        Error(_) -> {
          wisp.log_warning("No service found for request path: " <> req.path)
          wisp.not_found()
        }
      }
    }

    _ -> wisp.not_found()
  }
}

fn find_service(services: List(Service), name: String) -> Result(Service, Nil) {
  list.find(services, fn(service) { service.name == name })
}

fn forward_request(url: String, input_req: Request) -> Response {
  wisp.log_info("Forwarding request to URL: " <> url)

  use body <- wisp.require_string_body(input_req)

  case request.to(url) {
    Ok(req) -> send(map_request(input_req, req, body))
    Error(_) -> {
      wisp.log_error("Server error when trying to create a request to: " <> url)
      wisp.internal_server_error()
    }
  }

}

fn send(request: request.Request(String)) -> Response {
  case httpc.send(request) {
    Ok(response) -> wisp.json_response(string_builder.from_string(response.body), response.status)
    Error(_) -> {
      let url = request.host <> request.path
      wisp.log_error("Server error when trying to send a request to: " <> url)
      wisp.internal_server_error()
    }
  }
}

fn map_request(input: Request, output: request.Request(String), body: String) -> request.Request(String) {
  set_request_headers(
    input,
    request.set_body(
      request.set_method(
        output,
        input.method
      ),
      body
    )
  )
}

fn set_request_headers(input: Request, output: request.Request(String)) -> request.Request(String) {
  list.fold(input.headers, output, fn(req, header) {
    case string.lowercase(header.0) {
      "content-type" -> request.set_header(req, "content-type", header.1)
      _ -> req
    }
  })
}