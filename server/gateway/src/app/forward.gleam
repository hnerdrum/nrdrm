import app/transport.{type Transport}
import config/service.{type Service}
import gleam/bit_array
import gleam/bytes_tree
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/string
import gleam/string_tree
import wisp.{type Request, type Response}

pub fn forward_request(
  transport: Transport,
  service: Service,
  path: String,
  wisp_request: Request,
) -> Response {
  let url = service.create_url(service, path)
  wisp.log_info("Forwarding request to URL: " <> url)

  use body <- wisp.require_bit_array_body(wisp_request)

  case request.to(url) {
    Ok(req) ->
      send_request(
        transport,
        service,
        map_request(service, wisp_request, req, body),
      )
    Error(_) -> {
      wisp.log_error("Could not create request from URL: " <> url)
      wisp.internal_server_error()
    }
  }
}

pub fn send_request(
  transport: Transport,
  service: Service,
  request: request.Request(BitArray),
) -> Response {
  case transport(request) {
    Ok(response) -> map_response(service, response)
    Error(err) -> {
      let url = request.host <> request.path
      wisp.log_error(
        "Request to " <> url <> " got an error: " <> string.inspect(err),
      )
      case err {
        transport.Timeout -> wisp.response(504)
        transport.FailedToConnect(_) | transport.InvalidResponse ->
          wisp.response(502)
      }
    }
  }
}

fn map_request(
  service: Service,
  from: Request,
  to: request.Request(String),
  body: BitArray,
) -> request.Request(BitArray) {
  request.Request(..to, query: from.query)
  |> request.set_method(from.method)
  |> request.set_body(body)
  |> set_request_headers(from, service)
}

pub fn set_request_headers(
  to: request.Request(body),
  from: Request,
  service: Service,
) -> request.Request(body) {
  let forward_headers =
    list.filter(from.headers, fn(header) {
      list.contains(service.request.forward_headers, header.0)
    })
  list.fold(forward_headers, to, fn(acc, header) {
    request.set_header(acc, header.0, header.1)
  })
}

fn map_response(service: Service, from: response.Response(BitArray)) -> Response {
  wisp.response(from.status)
  |> response.set_body(wisp.Bytes(bytes_tree.from_bit_array(from.body)))
  |> set_response_headers(service, from, _)
}

fn set_response_headers(
  service: Service,
  from: response.Response(BitArray),
  to: Response,
) -> Response {
  list.fold_right(from.headers, to, fn(acc, header) {
    let #(name, value) = header
    let forwarded =
      name == "content-type"
      || list.contains(service.response.forward_headers, name)
    case forwarded {
      True -> response.prepend_header(acc, name, response_header(name, value))
      False -> acc
    }
  })
}

fn response_header(name: String, value: String) -> String {
  case name {
    "set-cookie" -> default_cookie_path(value)
    _ -> value
  }
}

fn default_cookie_path(cookie: String) -> String {
  let has_path =
    string.split(cookie, ";")
    |> list.any(fn(attribute) {
      string.trim(attribute) |> string.lowercase |> string.starts_with("path=")
    })
  case has_path {
    True -> cookie
    False -> cookie <> "; Path=/"
  }
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
