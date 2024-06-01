use dotenvy;
use std::env;
use std::str::FromStr;

#[derive(Debug)]
pub enum Environment {
  Dev,
  Prod
}

impl FromStr for Environment {
  type Err = ();

  fn from_str(s: &str) -> Result<Self, Self::Err> {
    match s {
      "Dev" => Ok(Environment::Dev),
      "Prod" => Ok(Environment::Prod),
      _ => Err(()),
    }
  }
}

#[derive(Debug)]
pub struct Config {
  pub env: Environment,
  pub port: String,
  pub database_url: String,
}

pub fn load_config() -> Config {
  let env = load_env();
  let port = env::var("PORT").unwrap_or("8081".to_string());
  let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
  Config { env: env, port: port, database_url: database_url}
}

fn load_env() -> Environment {
  match get_env() {
    Environment::Dev => {
      let _ = dotenvy::dotenv();
      Environment::Dev
    },
    Environment::Prod => Environment::Prod
  }
}

fn get_env() -> Environment {
  match env::var("ENV") {
    Ok(env) => Environment::from_str(&env).unwrap_or(Environment::Dev),
    Err(_) => Environment::Dev
  }
}