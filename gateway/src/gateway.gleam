import gleam/erlang/process
import mist
import wisp
import app/router

pub fn main() {
  wisp.configure_logger()

  // TODO: load this from somewhere real
  let secret_key_base = wisp.random_string(64)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp.mist_handler(router.handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
