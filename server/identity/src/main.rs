mod config;
use config::load_config;
mod router;
use router::init_router;

#[tokio::main]
async fn main() {
    let config = load_config();
    let port = config.port;
    let app = init_router();
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}")).await.unwrap();

    axum::serve(listener, app).await.unwrap();
}
