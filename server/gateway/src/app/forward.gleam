import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/list
import gleam/string
import gleam/string_builder
import gleam/result
import gleam/dynamic
import config/service.{type Service}
import wisp.{type Request, type Response}

pub fn forward_request(service: Service, path: String, wisp_request: Request) -> Response {
  let url = service.create_url(service, path)
  wisp.log_info("Forwarding request to URL: " <> url)

  use body <- wisp.require_string_body(wisp_request)

  case request.to(url) {
    Ok(req) -> send_request(service, map_request(service, wisp_request, req, body))
    Error(_) -> {
      wisp.log_error("Server error when trying to create a request to: " <> url)
      wisp.internal_server_error()
    }
  }

}

pub fn send_request(service: Service, request: request.Request(String)) -> Response {
  case httpc.send(request) {
    Ok(response) -> map_response(service, response)
    Error(err) -> {
      let url = request.host <> request.path
      let err_string = dynamic.string(err)
        |> result.unwrap("Unknown error")
      wisp.log_error("Error: " <> err_string)
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

pub fn set_request_headers(to: request.Request(String), from: Request, service: Service) -> request.Request(String) {
  let forward_headers = list.filter(from.headers, fn(header) {
    list.contains(service.request.forward_headers, header.0)
  })
  list.fold(forward_headers, to, fn(acc, header) {
    request.set_header(acc, header.0, header.1)
  })
}

fn map_response(service: Service, from: response.Response(String)) -> Response {
  let json_response = wisp.json_response(string_builder.from_string(from.body), from.status)
  set_cookie_header(set_response_headers(service, from, json_response))
  //json_response
}

fn set_response_headers(service: Service, from: response.Response(String), to: Response) -> Response {
  let forward_headers = list.filter(from.headers, fn(header) {
    list.contains(service.response.forward_headers, header.0)
  })
  list.fold(forward_headers, to, fn(acc, header) {
    response.set_header(acc, header.0, header.1)
  })
}

pub fn set_cookie_header(response: Response) -> Response {
  // Find Set-Cookie headers
  let headers = response.headers
  
  // Process each header
  let updated_response = 
    list.fold(headers, response, fn(acc, header) {
      let header_name = header.0
      let header_value = header.1
      
      // Check if this is a Set-Cookie header
      case string.lowercase(header_name) {
        "set-cookie" -> {          
          // Check if the cookie already has a path
          case string.contains(header_value, "path=") {
            True -> {
              // Already has a path, keep it as is
              response.set_header(acc, header_name, header_value)
            }
            False -> {
              // No path, add Path=/
              let new_value = string.concat([header_value, "; Path=/"])
              response.set_header(acc, header_name, new_value)
            }
          }
        }
        // Not a Set-Cookie header, keep as is
        _ -> acc
      }
    })
    
  updated_response
}