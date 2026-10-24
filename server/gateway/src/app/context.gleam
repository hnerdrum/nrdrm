import app/transport.{type Transport}
import config/config.{type Config}
import config/service.{type Service}

pub type Context {
  Context(
    services: List(Service),
    identity_service: Service,
    config: Config,
    transport: Transport,
  )
}
