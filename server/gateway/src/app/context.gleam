import app/transport.{type Transport}
import config/config.{type Config}
import config/routing.{type Routing}

pub type Context {
  Context(routing: Routing, config: Config, transport: Transport)
}
