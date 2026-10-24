import config/env.{Dev, Prod}
import config/service
import gleam/list
import gleeunit/should

pub fn dev_services_config_loads_test() {
  let assert Ok(services) = service.load_services(Dev)
  list.map(services, fn(service) { service.name })
  |> should.equal(["recipes", "identity", "agents"])
}

pub fn prod_services_config_loads_test() {
  let assert Ok(services) = service.load_services(Prod)
  list.map(services, fn(service) { service.name })
  |> should.equal(["recipes", "identity", "agents"])
}
