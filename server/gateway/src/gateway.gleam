import app/context.{Context}
import app/router
import app/transport
import config/config
import config/routing
import envoy
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/string
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let config = config.load_config() |> or_exit
  let routing = routing.load("gateway.json", envoy.get) |> or_exit
  let ctx = Context(routing, config, transport.new())

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request(_, ctx), config.secret_key_base)
    |> mist.new
    |> mist.port(config.port)
    |> mist.start_http

  process.sleep_forever()
}

fn or_exit(result: Result(a, List(String))) -> a {
  case result {
    Ok(value) -> value
    Error(errors) -> {
      io.println_error(
        "gateway cannot start:\n"
        <> string.join(list.map(errors, fn(error) { "  - " <> error }), "\n"),
      )
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> a
