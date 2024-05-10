import config/service.{type Service}
import cors_builder as cors
import gleam/http
import wisp

pub type Context {
  Context(services: List(Service), allowed_origin: String)
}

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response
) -> wisp.Response {
  let req = wisp.method_override(req)

  use <- wisp.log_request(req)

  use <- wisp.rescue_crashes

  use req <- cors.wisp_handle(req, cors(ctx.allowed_origin))

  use req <- wisp.handle_head(req)

  handle_request(req)
}

fn cors(allowed_origin: String) {
  cors.new()
  |> cors.allow_origin(allowed_origin)
  |> cors.allow_credentials()
  |> cors.allow_header("content-type")
  |> cors.allow_header("credentials")
  |> cors.allow_method(http.Get)
  |> cors.allow_method(http.Post)
  |> cors.allow_method(http.Put)
  |> cors.allow_method(http.Delete)
  |> cors.allow_method(http.Options)
}