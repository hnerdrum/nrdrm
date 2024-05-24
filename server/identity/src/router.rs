//use crate::domain::{UserSettings, Auth};
use axum::{Router, routing::get, Json};
use serde::Serialize;
use uuid::Uuid;

pub fn init_router() -> Router {
  Router::new()
    .nest("/api/v1",
      Router::new().route("/me", get(me_handler))
    )
}

async fn me_handler() -> Json<UserSettings> {
  Json(UserSettings { auth: Some(Auth { user_id: Uuid::new_v4() }) })
}


#[derive(Serialize)]
pub struct UserSettings {
  pub auth: Option<Auth>
}

#[derive(Serialize)]
pub struct Auth {
  pub user_id: Uuid
}