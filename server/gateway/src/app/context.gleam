import config/service.{type Service}
import config/config.{type Config}

pub type Context {
  Context(
    services: List(Service),
    identity_service: Service,
    config: Config
  )
}
