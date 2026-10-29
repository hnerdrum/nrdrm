import app/middleware
import app/route.{type Match}
import app/transport.{type Transport}
import config/routing.{type Route}
import gleam/bytes_tree
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/set
import gleam/string
import wisp.{type Request, type Response}

pub fn forward_request(
  transport: Transport,
  match: Match,
  wisp_request: Request,
) -> Response {
  let route = match.route
  let req = routing.upstream_request(route.upstream, match.path)

  use body <- wisp.require_bit_array_body(wisp_request)

  let req = map_request(route, wisp_request, req, body)
  case transport(req, route.upstream.timeout_ms) {
    Ok(response) -> map_response(route, response)
    Error(err) -> {
      wisp.log_error(
        "Request to "
        <> req.host
        <> req.path
        <> " got an error: "
        <> string.inspect(err),
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
  route: Route,
  from: Request,
  to: request.Request(BitArray),
  body: BitArray,
) -> request.Request(BitArray) {
  let forward_headers =
    list.filter(from.headers, fn(header) {
      set.contains(route.request_headers, header.0)
      || middleware.is_gateway_header(header.0)
    })
  request.Request(..to, query: from.query)
  |> request.set_method(from.method)
  |> request.set_body(body)
  |> list.fold(forward_headers, _, fn(acc, header) {
    request.set_header(acc, header.0, header.1)
  })
}

fn map_response(route: Route, from: response.Response(BitArray)) -> Response {
  wisp.response(from.status)
  |> response.set_body(wisp.Bytes(bytes_tree.from_bit_array(from.body)))
  |> set_response_headers(route, from, _)
}

fn set_response_headers(
  route: Route,
  from: response.Response(BitArray),
  to: Response,
) -> Response {
  list.fold_right(from.headers, to, fn(acc, header) {
    let #(name, value) = header
    let forwarded =
      name == "content-type" || set.contains(route.response_headers, name)
    case forwarded {
      True -> response.prepend_header(acc, name, response_header(name, value))
      False -> acc
    }
  })
}

fn response_header(name: String, value: String) -> String {
  case name {
    "set-cookie" -> middleware.ensure_cookie_path(value)
    _ -> value
  }
}
