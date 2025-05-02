import config/service.{type Service}

pub type Context {
  Context(services: List(Service), identity_service: Service, allowed_origins: List(String))
}
