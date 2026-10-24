import app/context.{Context}
import app/router
import app/transport
import config/config
import config/service
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

const upstream_timeout_ms = 120_000

pub fn main() {
  wisp.configure_logger()

  let config = config.load_config()
  let assert Ok(services) = service.load_services(config.env)
  let assert Ok(identity_service) = service.find(services, "identity")
  let ctx =
    Context(
      services,
      identity_service,
      config,
      transport.new(timeout_ms: upstream_timeout_ms),
    )

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request(_, ctx), config.secret_key_base)
    |> mist.new
    |> mist.port(config.port)
    |> mist.start_http

  process.sleep_forever()
}
