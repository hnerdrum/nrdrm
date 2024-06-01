use crate::domain::model::{login_user, Auth, UserSettings, LoginInput, LoginError};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Router, routing::post, Json, extract::State};
use deadpool_diesel::postgres::Pool;
use sha2::{Sha256, Digest};
use base64::{Engine, engine::general_purpose::STANDARD}; // For standard Base64
use std::fmt::Write;
use tower_cookies::{Cookie, CookieManagerLayer, Cookies};
use tower_http::compression::CompressionLayer;
use tower_http::trace::TraceLayer;

const AUTH_COOKIE_NAME: &str = "nrdrm-login";

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
        .route("/login", post(login_handler))
    )
    .layer(TraceLayer::new_for_http())
    .layer(CompressionLayer::new())
    .layer(CookieManagerLayer::new())
    .with_state(state)
}

async fn login_handler (cookies: Cookies, State(state): State<AppState>, Json(input): Json<LoginInput>) -> Result<Json<UserSettings>, LoginError> {
  login_user(state.db, input)
    .await
    .map(|user| { handle_valid_user(user, cookies) })
}

fn handle_valid_user(user: UserSettings, cookies: Cookies) -> Json<UserSettings> {
   user.auth.clone().inspect(|auth| {
     cookies.add(Cookie::new(AUTH_COOKIE_NAME, generate_token(auth.clone())));
   });
  Json(user)
}

fn generate_token(auth: Auth) -> String {
  let mut hasher = Sha256::new();

  let mut input_data = String::new();
  write!(input_data, "{}", auth.user_id).expect("Failed to write user ID");
  input_data.push_str(&auth.email);

  hasher.update(input_data.as_bytes());
  let result = hasher.finalize();

  // Encode the hash result as Base64
  STANDARD.encode(result)
}
