use tracing::info;
use training::config::load_config;
use training::database::connection::create_connection_pool;
use training::router::main::{init_router, AppState};

#[tokio::main]
async fn main() {
    let config = load_config();

    tracing_subscriber::fmt()
        .with_env_filter(config.log_level.clone())
        .init();

    let port = config.port.clone();
    let pool = create_connection_pool(config.database_url.clone());
    let app = init_router(AppState { db: pool, config });
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}"))
        .await
        .unwrap();

    info!("Starting server on 0.0.0.0:{port}");
    axum::serve(listener, app).await.unwrap();
}
