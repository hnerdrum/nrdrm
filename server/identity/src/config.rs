use dotenvy;
use std::env;
use std::str::FromStr;
use chrono::Utc;

#[derive(Debug, Clone)]
pub enum Environment {
  Dev,
  Prod
}

impl FromStr for Environment {
  type Err = ();

  fn from_str(s: &str) -> Result<Self, Self::Err> {
    match s {
      "dev" => Ok(Environment::Dev),
      "prod" => Ok(Environment::Prod),
      _ => Err(()),
    }
  }
}

#[derive(Debug, Clone)]
pub struct Config {
  pub env: Environment,
  pub port: String,
  pub database_url: String,
  pub log_level: String,
  pub auth: AuthConfig,
  pub boot_time: String,
  pub api_version: String
}

#[derive(Debug, Clone)]
pub struct AuthConfig {
  pub secret: String,
  pub cookie_name: String
}

pub fn load_config() -> Config {
  let env = load_env();
  let port = env::var("APP_PORT").unwrap_or("8080".to_string());
  let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
  let log_level = env::var("LOG_LEVEL").unwrap_or("tower_http=debug,axum=debug,info".to_string());
  let auth_secret = env::var("AUTH_SECRET").expect("AUTH_SECRET must be set");
  let build_id = env::var("BUILD_ID").unwrap_or("dev".to_string());
  Config {
    env,
    port,
    database_url,
    log_level,
    auth: AuthConfig { secret: auth_secret, cookie_name: "nrdrm-login".to_string() },
    boot_time: Utc::now().to_rfc3339(),
    api_version: build_id.chars().take(7).collect()
  }
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
