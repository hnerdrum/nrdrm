import gleam/hackney
import gleam/http.{Get}
import gleam/http/request
import gleam/string_builder
import wisp.{type Request, type Response}
import app/web

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> hello_world(req)

    ["recipes"] -> recipes(req)

    _ -> wisp.not_found()
  }
}

fn hello_world(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let body = string_builder.from_string("Hello, world!")

  wisp.json_response(body, 200)
}

fn recipes(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let url = "https://api.nrdrm.dev/api/v1/recipes"

  forward_request(url)
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