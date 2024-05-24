use crate::domain::model::{UserSettings, Auth};
use axum::{Router, routing::get, Json};
use tower_http::compression::CompressionLayer;
use tower_http::trace::TraceLayer;
use uuid::Uuid;

pub fn init_router() -> Router {
  Router::new()
    .nest("/api/v1",
      Router::new().route("/me", get(me_handler))
    )
    .layer(TraceLayer::new_for_http())
    .layer(CompressionLayer::new())
}

async fn me_handler() -> Json<UserSettings> {
  Json(UserSettings { auth: Some(Auth { user_id: Uuid::new_v4() }) })
}
