mod router;
use router::init_router;

#[tokio::main]
async fn main() {
    let app = init_router();
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8081").await.unwrap();

    axum::serve(listener, app).await.unwrap();
}
