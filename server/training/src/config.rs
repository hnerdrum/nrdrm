use dotenvy;
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub port: String,
    pub database_url: String,
    pub log_level: String,
    pub garmin_api_key: String,
}

pub fn load_config() -> Config {
    load_dotenv();
    let port = env::var("APP_PORT").unwrap_or_else(|_| "8082".to_string());
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let log_level =
        env::var("LOG_LEVEL").unwrap_or_else(|_| "tower_http=debug,axum=debug,info".to_string());
    let garmin_api_key = env::var("GARMIN_API_KEY").unwrap_or_default();
    Config {
        port,
        database_url,
        log_level,
        garmin_api_key,
    }
}

fn load_dotenv() {
    if env::var("ENV").ok().as_deref() == Some("prod") {
        return;
    }
    let _ = dotenvy::dotenv();
}
