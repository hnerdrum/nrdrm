
pub type ServiceConfig {
  ServiceConfig(name: String, base_url: String)
}

pub fn load_service_config() {
  services
}

pub fn create_url(service: ServiceConfig, path: String) -> String {
  service.base_url <> "/" <> path
}

const services = [
  ServiceConfig("recipes", "https://recipes.api.nrdrm.dev/api/v1"),
]