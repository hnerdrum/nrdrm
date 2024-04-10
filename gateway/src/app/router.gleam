import wisp.{type Request, type Response}
import gleam/string_builder
import gleam/http.{Get}
import app/web

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> hello_world(req)

    _ -> wisp.not_found()
  }
}

fn hello_world(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  let body = string_builder.from_string("Hello, world!")

  wisp.json_response(body, 200)
}