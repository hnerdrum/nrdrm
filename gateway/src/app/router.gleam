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

fn map_request(service: Service, input: Request, output: request.Request(String), body: String) -> request.Request(String) {
  set_request_headers(
    service,
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

fn set_request_headers(service: Service, input: Request, output: request.Request(String)) -> request.Request(String) {
  let forward_headers = list.filter(input.headers, fn(header) {
    list.contains(service.request.forward_headers, header.0)
  })
  list.fold(forward_headers, output, fn(req, header) {
    request.set_header(req, header.0, header.1)
  })
}

fn map_response(service: Service, input: response.Response(String)) -> Response {
  let json_response = wisp.json_response(string_builder.from_string(input.body), input.status)
  set_response_headers(service, input, json_response)
}

fn set_response_headers(service: Service, input: response.Response(String), output: Response) -> Response {
  let forward_headers = list.filter(input.headers, fn(header) {
    list.contains(service.response.forward_headers, header.0)
  })
  list.fold(forward_headers, output, fn(res, header) {
    response.set_header(res, header.0, header.1)
  })
}