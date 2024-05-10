import app/web.{Context}
import app/router
import config/config
import config/services
import gleam/erlang/process
import mist
import wisp

pub fn main() {
  wisp.configure_logger()

  let config = config.load_config()
  let assert Ok(services) = services.load_services(config.env)
  let ctx = Context(services)

  let assert Ok(_) =
    wisp.mist_handler(router.handle_request(_, ctx), config.secret_key_base)
    |> mist.new
    |> mist.port(config.port)
    |> mist.start_http

  process.sleep_forever()
}
