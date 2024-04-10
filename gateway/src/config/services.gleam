
pub type ServiceConfig {
  ServiceConfig(name: String, base_url: String)
}

pub fn load_service_config() {
  services
}

const services = [
  ServiceConfig("recipes", "https://api.nrdrm.dev/api/v1/recipes"),
]