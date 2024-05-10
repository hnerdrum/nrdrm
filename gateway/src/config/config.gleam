import dotenv_gleam
import gleam/erlang/os
import gleam/int
import gleam/result
import config/env.{type Environment, Dev, Prod}

pub type Config {
  Config(port: Int, secret_key_base: String, env: Environment)
}

pub fn load_config() -> Config {
  let env = load_env()

  let assert Ok(port) = result.flatten(result.map(get_env("PORT"), parse_int))
  let assert Ok(secret_key_base) = get_env("SECRET_KEY_BASE")

  Config(port, secret_key_base, env)
}

fn load_env() -> Environment {
  case get_environment() {
    Dev -> {
      dotenv_gleam.config()
      Dev
    }
    Prod -> Prod
  }
}

fn get_environment() -> Environment {
  result.unwrap(handle_result(get_env("ENV"), env.parse_env), Dev)
}

fn handle_result(result: Result(a, b), next_fn: fn(a) -> Result(c, b)) -> Result(c, b) {
  case result {
    Ok(value) -> next_fn(value)
    Error(error) -> Error(error)
  }
}

fn parse_int(str: String) -> Result(Int, String) {
  result.map_error(int.base_parse(str, 10), fn(_) { "Could not parse string " <> str <> " to int"})
}

fn get_env(name: String) -> Result(String, String) {
  result.map_error(os.get_env(name), fn(_) { "Environment variable " <> name <> " not found" })
}