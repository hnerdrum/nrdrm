use crate::config::Config;
use crate::domain::error::DomainError;
use crate::domain::jwt::create_jwt_token;
use crate::domain::model::{login_user, Auth, HealthCheck, LoginInput, TokenValidation, User, UserSettings};
use crate::database::auth_token::create_auth_token;
use super::middleware::auth_middleware;
use axum::http::StatusCode;
use axum::{middleware, Extension};
use axum::response::IntoResponse;
use axum::{Router, routing::post, routing::get, Json, extract::State};
use deadpool_diesel::postgres::Pool;
use tracing::error;
use tower_cookies::{Cookie, CookieManagerLayer, Cookies};
use tower_http::compression::CompressionLayer;
use tower_http::trace::{self, TraceLayer};

#[derive(Clone)]
pub struct AppState {
  pub db: Pool,
  pub config: Config
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

async fn health_handler(State(state): State<AppState>) -> Result<Json<HealthCheck>, DomainError> {
  Ok(Json(HealthCheck { boot_time: state.config.boot_time, api_version: state.config.api_version }))
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
  handle_valid_user(state, user, cookies).await
}

async fn handle_valid_user(state: AppState, user: User, cookies: Cookies) -> Result<Json<User>, DomainError> {
  let auth_token = create_auth_token(&state.db, user.clone()).await.map_err(|err| {
    error!("Encountered unexpected database error: {:?}", err);
    DomainError::UnknownError
  })?;
  let token = create_jwt_token(user.clone(), auth_token.clone(), state.config.auth.secret.clone())?;

  cookies.add(Cookie::new(state.config.auth.cookie_name.clone(), token));
  Ok(Json(user))
}
