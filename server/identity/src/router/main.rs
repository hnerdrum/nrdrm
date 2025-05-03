use crate::database::connection::DBClient;
use crate::domain::model::{login_user, Auth, LoginError, LoginInput, TokenValidation, User, UserSettings};
use crate::database::auth_token::upsert_user_auth_token;
use super::middleware::auth_middleware;
use axum::http::StatusCode;
use axum::{middleware, Extension};
use axum::response::IntoResponse;
use axum::{Router, routing::post, routing::get, Json, extract::State};
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
        .route("/health", get(health_handler))
        .route("/validate-token", get(validate_token_handler))
        .route("/me", get(me_handler))
        .route("/login", post(login_handler))
    )
    .layer(TraceLayer::new_for_http())
    .layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
    .layer(CompressionLayer::new())
    .layer(CookieManagerLayer::new())
    .with_state(state)
}

async fn health_handler() -> &'static str {
  "OK"
}

async fn validate_token_handler (Extension(auth): Extension<Option<Auth>>) -> Result<Json<TokenValidation>, LoginError> {
  match auth {
    Some(_) => Ok(Json(TokenValidation { valid: true })),
    None => Ok(Json(TokenValidation { valid: false }))
  }
}

async fn me_handler (Extension(auth): Extension<Option<Auth>>) -> Json<UserSettings> {
  Json(UserSettings { auth })
}

async fn login_handler(cookies: Cookies, State(state): State<AppState>, Json(input): Json<LoginInput>) -> Result<Json<User>, LoginError> {
  let user = login_user(state.db.clone(), input).await?;
  handle_valid_user(state.db.clone(), user, cookies)
    .await
    .map_err(|_| {
      LoginError::UnknownError
    })
}

async fn handle_valid_user(db: DBClient, user: User, cookies: Cookies) -> Result<Json<User>, String> {
  let token = generate_token(user.clone());
  upsert_user_auth_token(&db, user.clone(), token.clone()).await?;
  cookies.add(Cookie::new(AUTH_COOKIE_NAME, token));
  Ok(Json(user))
}

fn generate_token(user: User) -> String {
  let mut hasher = Sha256::new();

  let mut input_data = String::new();
  write!(input_data, "{}", user.id).expect("Failed to write user ID");
  input_data.push_str(&user.email);

  hasher.update(input_data.as_bytes());
  let result = hasher.finalize();

  // Encode the hash result as Base64
  STANDARD.encode(result)
}
