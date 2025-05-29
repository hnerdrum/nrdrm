import gleam/string
import gleam/result
import gleam/dynamic/decode
import gleam/json

pub type HealthCheck {
  HealthCheck(
    boot_time: String,
    api_version: String
  )
}

pub fn to_json(health_check: HealthCheck) {
  json.object([
      #("boot_time", json.string(health_check.boot_time)),
      #("api_version", json.string(health_check.api_version))
  ])
}

pub fn from_json_string(json_string: String) {
  result.map_error(json.parse(json_string, health_check_decoder()), fn(err) { "Error when decoding json into health check data" <> string.inspect(err) })
}

fn health_check_decoder() {
  use boot_time <- decode.field("boot_time", decode.string)
  use api_version <- decode.field("api_version", decode.string)
  decode.success(
    HealthCheck(boot_time, api_version)
  )
}