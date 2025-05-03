import app/context.{Context}
import app/router
import config/config
import config/service
import gleam/erlang/process
import mist
import wisp

pub fn main() {
  wisp.configure_logger()

  let config = config.load_config()
  let assert Ok(services) = service.load_services(config.env)
  let assert Ok(identity_service) = service.find(services, "identity")
  let ctx = Context(services, identity_service, config.allowed_origins)

  let assert Ok(_) =
    wisp.mist_handler(router.handle_request(_, ctx), config.secret_key_base)
    |> mist.new
    |> mist.port(config.port)
    |> mist.start_http

  process.sleep_forever()
}
