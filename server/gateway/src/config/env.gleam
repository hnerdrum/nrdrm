
pub type Environment {
  Dev
  Prod
}

pub fn parse_env(str: String) -> Result(Environment, String) {
  case str {
    "dev" -> Ok(Dev)
    "prod" -> Ok(Prod)
    _ -> Error("Could not parse string " <> str <> " into environment type")
  } 
}

pub fn to_string(env: Environment) -> String {
  case env {
    Dev -> "dev"
    Prod -> "prod"
  }
}