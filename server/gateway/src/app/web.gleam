import cors_builder as cors
import gleam/http
import gleam/list
import wisp
import app/middleware.{auth_middleware}
import app/context.{type Context}

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

  use req <- auth_middleware(req, ctx)

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