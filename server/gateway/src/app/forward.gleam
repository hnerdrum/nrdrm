import config/service.{type Service}
import gleam/bit_array
import gleam/bytes_tree
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/string_tree
import wisp.{type Request, type Response}

pub fn forward_request(
  service: Service,
  path: String,
  wisp_request: Request,
) -> Response {
  let url = service.create_url(service, path)
  wisp.log_info("Forwarding request to URL: " <> url)

  use body <- wisp.require_string_body(wisp_request)

  case request.to(url) {
    Ok(req) ->
      send_request(service, map_request(service, wisp_request, req, body))
    Error(_) -> {
      wisp.log_error("Could not create request from URL: " <> url)
      wisp.internal_server_error()
    }
  }
}

pub fn send_request(
  service: Service,
  request: request.Request(String),
) -> Response {
  case httpc.send(request) {
    Ok(response) -> map_response(service, response)
    Error(err) -> {
      let url = request.host <> request.path
      wisp.log_error(
        "Request to " <> url <> "got an error: " <> string.inspect(err),
      )
      wisp.internal_server_error()
    }
  }
}

fn map_request(
  service: Service,
  from: Request,
  to: request.Request(String),
  body: String,
) -> request.Request(String) {
  request.set_method(to, from.method)
  |> request.set_body(body)
  |> set_request_headers(from, service)
}

pub fn set_request_headers(
  to: request.Request(String),
  from: Request,
  service: Service,
) -> request.Request(String) {
  let forward_headers =
    list.filter(from.headers, fn(header) {
      list.contains(service.request.forward_headers, header.0)
    })
  list.fold(forward_headers, to, fn(acc, header) {
    request.set_header(acc, header.0, header.1)
  })
  |> set_hop_authorization(service)
}

pub fn set_hop_authorization(
  req: request.Request(String),
  service: Service,
) -> request.Request(String) {
  case service.request.authorization {
    Some(secret) ->
      request.set_header(req, "authorization", "Bearer " <> secret)
    None -> req
  }
}

fn map_response(service: Service, from: response.Response(String)) -> Response {
  let json_response =
    wisp.json_response(string_tree.from_string(from.body), from.status)
  set_cookie_header(set_response_headers(service, from, json_response))
}

fn set_response_headers(
  service: Service,
  from: response.Response(String),
  to: Response,
) -> Response {
  let forward_headers =
    list.filter(from.headers, fn(header) {
      list.contains(service.response.forward_headers, header.0)
    })
  list.fold(forward_headers, to, fn(acc, header) {
    response.set_header(acc, header.0, header.1)
  })
}

pub fn set_cookie_header(response: Response) -> Response {
  let headers = response.headers

  let updated_response =
    list.fold(headers, response, fn(acc, header) {
      let header_name = header.0
      let header_value = header.1

      case string.lowercase(header_name) {
        "set-cookie" -> {
          case string.contains(header_value, "path=") {
            True -> {
              response
            }
            False -> {
              let new_value = string.concat([header_value, "; Path=/"])
              response.set_header(acc, header_name, new_value)
            }
          }
        }
        _ -> acc
      }
    })

  updated_response
}

pub fn parse_string_response(response: Response) {
  case response.body {
    wisp.Text(text) -> Ok(string_tree.to_string(text))
    wisp.Bytes(bytes) -> {
      case bit_array.to_string(bytes_tree.to_bit_array(bytes)) {
        Ok(string) -> Ok(string)
        Error(_) -> Error("Invalid UTF-8 binary data")
      }
    }
    wisp.File(file_path) ->
      Error("Received file response at path: " <> file_path)
    wisp.Empty -> Ok("")
  }
}
