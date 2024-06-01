use crate::domain::model::{login_user, Auth, UserSettings, LoginInput, LoginError};
use crate::database::user_account::find_all;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Router, routing::{get, post}, Json, extract::State};
use deadpool_diesel::postgres::Pool;
use tower_http::compression::CompressionLayer;
use tower_http::trace::TraceLayer;
use uuid::Uuid;

#[derive(Clone)]
pub struct AppState {
  pub db: Pool
}

impl IntoResponse for LoginError {
  fn into_response(self) -> axum::response::Response {
      let (status, error_message) = match self {
        Self::InvalidCredentialsError => (
          StatusCode::UNAUTHORIZED, "Invalid credentials"
        ),        Self::UnknownError => (
          StatusCode::INTERNAL_SERVER_ERROR, "Unknown error"
        ),
      };
      (
        status,
        Json(error_message),
    )
        .into_response()
  }
}

pub fn init_router(state: AppState) -> Router {
  Router::new()
    .nest("/api/v1",
      Router::new()
        .route("/me", get(me_handler))
        .route("/login", post(login_handler))
    )
    .layer(TraceLayer::new_for_http())
    .layer(CompressionLayer::new())
    .with_state(state)
}

async fn me_handler(State(state): State<AppState>) -> Json<UserSettings> {
  let db = state.db;
  let users = find_all(&db).await;
  println!("users are here: {:?}", users);
  Json(UserSettings { auth: Some(Auth { user_id: Uuid::new_v4() }) })
}

async fn login_handler (State(state): State<AppState>, Json(input): Json<LoginInput>) -> Result<Json<UserSettings>, LoginError> {
  login_user(state.db, input)
    .await
    .map(|user| Json(user))
}
