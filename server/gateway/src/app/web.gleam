import app/clock
import app/context.{type Context}
import app/log
import app/middleware
import app/request_id
import config/routing.{type Route}
import cors_builder as cors
import gleam/dynamic
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/option.{type Option, None, Some}
import wisp

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  route: Option(Route),
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let started = clock.monotonic_ms()
  let id = request_id.from_request(req)
  log.set_request_id(id)

  let response =
    {
      use <- wisp.rescue_crashes

      use req <- cors.wisp_middleware(req, cors(ctx.config.allowed_origins))

      use req <- wisp.handle_head(req)

      middleware.strip_reserved_headers(req)
      |> request.set_header(request_id.header, id)
      |> handle_request
    }
    |> response.set_header(request_id.header, id)

  access_log(req, route, response.status, clock.monotonic_ms() - started)
  log.clear_request_id()
  response
}

fn access_log(
  req: wisp.Request,
  route: Option(Route),
  status: Int,
  duration_ms: Int,
) -> Nil {
  let #(prefix, upstream) = case route {
    Some(route) -> #(route.prefix, route.upstream.name)
    None -> #("", "")
  }
  log.info("request", [
    #("method", dynamic.string(http.method_to_string(req.method))),
    #("path", dynamic.string(req.path)),
    #("route", dynamic.string(prefix)),
    #("upstream", dynamic.string(upstream)),
    #("status", dynamic.int(status)),
    #("duration_ms", dynamic.int(duration_ms)),
  ])
}

fn cors(allowed_origins: List(String)) {
  let base_cors =
    cors.new()
    |> cors.allow_credentials()
    |> cors.allow_header("content-type")
    |> cors.allow_header("credentials")
    |> cors.allow_method(http.Get)
    |> cors.allow_method(http.Post)
    |> cors.allow_method(http.Put)
    |> cors.allow_method(http.Delete)
    |> cors.allow_method(http.Options)
    |> cors.expose_header(request_id.header)

  list.fold(allowed_origins, base_cors, fn(acc, origin) {
    cors.allow_origin(acc, origin)
  })
}
