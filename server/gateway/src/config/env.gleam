
pub type Environment {
  Dev
  Prod
}

pub fn parse_env(str: String) -> Result(Environment, Nil) {
  case str {
    "dev" -> Ok(Dev)
    "prod" -> Ok(Prod)
    _ -> Error(Nil)
  } 
}

pub fn to_string(env: Environment) -> String {
  case env {
    Dev -> "dev"
    Prod -> "prod"
  }
}