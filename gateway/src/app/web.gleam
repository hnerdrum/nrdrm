import config/service.{type Service}
import cors_builder as cors
import gleam/http
import gleam/list
import wisp

pub type Context {
  Context(services: List(Service), allowed_origins: List(String))
}

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response
) -> wisp.Response {
  let req = wisp.method_override(req)

  use <- wisp.log_request(req)

  use <- wisp.rescue_crashes

  use req <- cors.wisp_handle(req, cors(ctx.allowed_origins))

  use req <- wisp.handle_head(req)

  handle_request(req)
}

fn cors(allowed_origins: List(String)) {
  let base_cors = cors.new()
    |> cors.allow_credentials()
    |> cors.allow_header("content-type")
    |> cors.allow_header("credentials")
    |> cors.allow_method(http.Get)
    |> cors.allow_method(http.Post)
    |> cors.allow_method(http.Put)
    |> cors.allow_method(http.Delete)
    |> cors.allow_method(http.Options)

  list.fold(allowed_origins, base_cors, fn(acc, origin) {
    cors.allow_origin(acc, origin)
  })
}