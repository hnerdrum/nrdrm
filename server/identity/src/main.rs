mod config;
use config::load_config;
mod database;
use database::connection::create_connection_pool;
mod domain;
mod router;
use router::main::{init_router, AppState};

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let config = load_config();
    let port = config.port;

    let pool = create_connection_pool(config.database_url);

    let app = init_router(AppState { db: pool });
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}")).await.unwrap();

    axum::serve(listener, app).await.unwrap();
}
