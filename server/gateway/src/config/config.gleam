import dotenv_gleam
import gleam/int
import gleam/result
import gleam/string
import config/env.{type Environment, Dev, Prod}
import envoy
import gleam/time/timestamp
import gleam/time/calendar

pub type Config {
  Config(
    port: Int,
    secret_key_base: String,
    env: Environment,
    allowed_origins: List(String),
    boot_time: String,
    api_version: String
  )
}

pub fn load_config() -> Config {
  let env = load_env()


  let assert Ok(port) = result.flatten(result.map(envoy.get("PORT"), parse_int))
  let assert Ok(secret_key_base) = envoy.get("SECRET_KEY_BASE")
  let assert Ok(allowed_origins) = result.map(envoy.get("ALLOWED_ORIGINS"), parse_origins)

  Config(
    port,
    secret_key_base,
    env,
    allowed_origins,
    boot_time: timestamp.to_rfc3339(timestamp.system_time(), calendar.utc_offset),
    api_version: string.slice(result.unwrap(envoy.get("BUILD_ID"), "dev"), 0, 7)
  )
}

fn load_env() -> Environment {
  case get_environment() {
    Dev -> {
      let _ = dotenv_gleam.config()
      Dev
    }
    Prod -> Prod
  }
}

fn get_environment() -> Environment {
  result.unwrap(handle_result(envoy.get("ENV"), env.parse_env), Dev)
}

fn handle_result(result: Result(a, b), next_fn: fn(a) -> Result(c, b)) -> Result(c, b) {
  case result {
    Ok(value) -> next_fn(value)
    Error(error) -> Error(error)
  }
}

fn parse_int(str: String) -> Result(Int, Nil) {
  int.base_parse(str, 10)
}

fn parse_origins(str: String) -> List(String) {
  string.split(str, ",")
}
