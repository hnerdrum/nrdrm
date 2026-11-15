use dotenvy;
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub port: String,
    pub database_url: String,
    pub log_level: String,
    pub garmin_api_key: String,
    pub mcp_resource_url: String,
    pub authorization_server_url: String,
    pub training_owner_email: String,
    pub mcp_allowed_origins: Vec<String>,
}

pub fn load_config() -> Config {
    load_dotenv();
    let port = env::var("APP_PORT").unwrap_or_else(|_| "8082".to_string());
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let log_level =
        env::var("LOG_LEVEL").unwrap_or_else(|_| "tower_http=debug,axum=debug,info".to_string());
    let garmin_api_key = env::var("GARMIN_API_KEY").unwrap_or_default();
    let mcp_resource_url = env_or("MCP_RESOURCE_URL", "http://localhost:8080/training/mcp");
    let authorization_server_url =
        env_or("AUTHORIZATION_SERVER_URL", "http://localhost:8080/identity");
    let training_owner_email = env::var("TRAINING_OWNER_EMAIL")
        .unwrap_or_default()
        .trim()
        .to_string();
    let mcp_allowed_origins = allowed_origins(&env::var("MCP_ALLOWED_ORIGINS").unwrap_or_default());
    Config {
        port,
        database_url,
        log_level,
        garmin_api_key,
        mcp_resource_url,
        authorization_server_url,
        training_owner_email,
        mcp_allowed_origins,
    }
}

fn env_or(name: &str, default: &str) -> String {
    env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| default.to_string())
}

fn allowed_origins(value: &str) -> Vec<String> {
    value
        .split(',')
        .map(str::trim)
        .filter(|origin| !origin.is_empty())
        .map(str::to_string)
        .collect()
}

fn load_dotenv() {
    if env::var("ENV").ok().as_deref() == Some("prod") {
        return;
    }
    let _ = dotenvy::dotenv();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn origins_are_split_on_commas() {
        assert!(allowed_origins("").is_empty());
        assert_eq!(
            allowed_origins(" http://localhost:3000, https://nrdrm.no "),
            vec![
                "http://localhost:3000".to_string(),
                "https://nrdrm.no".to_string()
            ]
        );
    }
}
