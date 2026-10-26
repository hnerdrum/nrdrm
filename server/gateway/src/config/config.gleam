import config/env.{type Environment, Dev, Prod}
import dotenv_gleam
import envoy
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp

pub type Config {
  Config(
    port: Int,
    secret_key_base: String,
    env: Environment,
    allowed_origins: List(String),
    boot_time: String,
    api_version: String,
  )
}

pub fn load_config() -> Result(Config, List(String)) {
  let env = load_env()

  let port =
    required("PORT")
    |> result.try(fn(value) {
      parse_int(value)
      |> result.replace_error(
        "PORT must be an integer, got \"" <> value <> "\"",
      )
    })
  let secret_key_base = required("SECRET_KEY_BASE")
  let allowed_origins = required("ALLOWED_ORIGINS") |> result.map(parse_origins)

  case port, secret_key_base, allowed_origins {
    Ok(port), Ok(secret_key_base), Ok(allowed_origins) ->
      Ok(Config(
        port,
        secret_key_base,
        env,
        allowed_origins,
        boot_time: timestamp.to_rfc3339(
          timestamp.system_time(),
          calendar.utc_offset,
        ),
        api_version: string.slice(
          result.unwrap(envoy.get("BUILD_ID"), "dev"),
          0,
          7,
        ),
      ))
    _, _, _ ->
      Error(
        list.filter_map(
          [
            result.replace(port, Nil),
            result.replace(secret_key_base, Nil),
            result.replace(allowed_origins, Nil),
          ],
          fn(field) {
            case field {
              Ok(Nil) -> Error(Nil)
              Error(message) -> Ok(message)
            }
          },
        ),
      )
  }
}

fn required(name: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Ok(value)
    _ -> Error("environment variable " <> name <> " is not set")
  }
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

fn handle_result(
  result: Result(a, b),
  next_fn: fn(a) -> Result(c, b),
) -> Result(c, b) {
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
