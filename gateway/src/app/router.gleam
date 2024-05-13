import gleam/http/request
import gleam/http/response
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
      list.each(services, fn(service) { forward_request(service, "health", req) })
      wisp.ok()
    }

    [service_name, ..path_segments] -> {
      case service.find(services, service_name) {
        Ok(service) -> forward_request(service, string.join(path_segments, "/"), req)
        Error(_) -> {
          wisp.log_warning("No service found for request path: " <> req.path)
          wisp.not_found()
        }
      }
    }

    _ -> wisp.not_found()
  }
}

fn forward_request(service: Service, path: String, wisp_request: Request) -> Response {
  let url = service.create_url(service, path)
  wisp.log_info("Forwarding request to URL: " <> url)

  use body <- wisp.require_string_body(wisp_request)

  case request.to(url) {
    Ok(req) -> send(service, map_request(service, wisp_request, req, body))
    Error(_) -> {
      wisp.log_error("Server error when trying to create a request to: " <> url)
      wisp.internal_server_error()
    }
  }

}

fn send(service: Service, request: request.Request(String)) -> Response {
  case httpc.send(request) {
    Ok(response) -> map_response(service, response)
    Error(_) -> {
      let url = request.host <> request.path
      wisp.log_error("Server error when trying to send a request to: " <> url)
      wisp.internal_server_error()
    }
  }
}

fn map_request(service: Service, from: Request, to: request.Request(String), body: String) -> request.Request(String) {
  request.set_method(to, from.method)
    |> request.set_body(body)
    |> set_request_headers(from, service)
}

fn set_request_headers(to: request.Request(String), from: Request, service: Service) -> request.Request(String) {
  let forward_headers = list.filter(from.headers, fn(header) {
    list.contains(service.request.forward_headers, header.0)
  })
  list.fold(forward_headers, to, fn(req, header) {
    request.set_header(req, header.0, header.1)
  })
}

fn map_response(service: Service, from: response.Response(String)) -> Response {
  let json_response = wisp.json_response(string_builder.from_string(from.body), from.status)
  set_response_headers(service, from, json_response)
}

fn set_response_headers(service: Service, from: response.Response(String), to: Response) -> Response {
  let forward_headers = list.filter(from.headers, fn(header) {
    list.contains(service.response.forward_headers, header.0)
  })
  list.fold(forward_headers, to, fn(res, header) {
    response.set_header(res, header.0, header.1)
  })
}