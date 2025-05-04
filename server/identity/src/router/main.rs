use crate::database::connection::DBClient;
use crate::domain::error::DomainError;
use crate::domain::model::{login_user, Auth, LoginInput, TokenValidation, User, UserSettings};
use crate::database::auth_token::upsert_user_auth_token;
use super::middleware::auth_middleware;
use axum::http::StatusCode;
use axum::{middleware, Extension};
use axum::response::IntoResponse;
use axum::{Router, routing::post, routing::get, Json, extract::State};
use deadpool_diesel::postgres::Pool;
use sha2::{Sha256, Digest};
use base64::{Engine, engine::general_purpose::STANDARD};
use tracing::error;
use std::fmt::Write;
use tower_cookies::{Cookie, CookieManagerLayer, Cookies};
use tower_http::compression::CompressionLayer;
use tower_http::trace::{self, TraceLayer};

const AUTH_COOKIE_NAME: &str = "nrdrm-login";

#[derive(Clone)]
pub struct AppState {
  pub db: Pool
}

impl IntoResponse for DomainError {
  fn into_response(self) -> axum::response::Response {
      let (status, error_message) = match self {
        Self::InvalidCredentialsError => (
          StatusCode::UNAUTHORIZED, "Invalid credentials"
        ),        Self::UnknownError => (
          StatusCode::INTERNAL_SERVER_ERROR, "Internal server error"
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
    .layer(
      TraceLayer::new_for_http()
          .make_span_with(trace::DefaultMakeSpan::new()
              .include_headers(true))
          .on_response(trace::DefaultOnResponse::new()
              .include_headers(true)
              .latency_unit(tower_http::LatencyUnit::Micros))
    )
    .layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
    .layer(CompressionLayer::new())
    .layer(CookieManagerLayer::new())
    .with_state(state)
}

async fn health_handler() -> &'static str {
  "OK"
}

async fn validate_token_handler (Extension(auth): Extension<Option<Auth>>) -> Result<Json<TokenValidation>, DomainError> {
  match auth {
    Some(_) => Ok(Json(TokenValidation { valid: true })),
    None => Ok(Json(TokenValidation { valid: false }))
  }
}

async fn me_handler (Extension(auth): Extension<Option<Auth>>) -> Json<UserSettings> {
  Json(UserSettings { auth })
}

async fn login_handler(cookies: Cookies, State(state): State<AppState>, Json(input): Json<LoginInput>) -> Result<Json<User>, DomainError> {
  let user = login_user(state.db.clone(), input).await?;
  handle_valid_user(state.db.clone(), user, cookies).await
}

async fn handle_valid_user(db: DBClient, user: User, cookies: Cookies) -> Result<Json<User>, DomainError> {
  let token = generate_token(user.clone());
  upsert_user_auth_token(&db, user.clone(), token.clone()).await.map_err(|err| {
    error!("Encountered unexpected database error: {:?}", err);
    DomainError::UnknownError
  })?;
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

  STANDARD.encode(result)
}
