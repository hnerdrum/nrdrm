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

    println!("Loading configuration");
    let config = load_config();
    let port = config.port;
    println!("Configured to listen on port: {}", port);

    println!("Creating database connection pool");
    let pool = create_connection_pool(config.database_url);

    println!("Initializing router");
    let app = init_router(AppState { db: pool });
    println!("Binding to 0.0.0.0:{}", port);
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}")).await.unwrap();

    println!("Starting server");
    axum::serve(listener, app).await.unwrap();
}
