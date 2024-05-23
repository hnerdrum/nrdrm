use axum::{Router, routing::get};

pub fn init_router() -> Router {
  Router::new()
      .route("/", get(hello_world))
}

async fn hello_world() -> &'static str {
  "Hello world!"
}