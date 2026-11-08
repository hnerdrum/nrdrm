use super::middleware::{auth_middleware, session_cookie};
use crate::config::Config;
use crate::database::auth_token::create_auth_token;
use crate::domain::error::DomainError;
use crate::domain::jwt::create_jwt_token;
use crate::domain::model::{
    login_user, Auth, HealthCheck, LoginInput, TokenValidation, User, UserSettings,
};
use crate::domain::oauth::{
    introspect_access_token, issue_access_token, IntrospectRequest, Introspection, TokenRequest,
    TokenResponse,
};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{extract::State, routing::get, routing::post, Json, Router};
use axum::{middleware, Extension};
use deadpool_diesel::postgres::Pool;
use tower_cookies::{CookieManagerLayer, Cookies};
use tower_http::compression::CompressionLayer;
use tower_http::trace::{self, TraceLayer};
use tracing::error;

#[derive(Clone)]
pub struct AppState {
    pub db: Pool,
    pub config: Config,
}

impl IntoResponse for DomainError {
    fn into_response(self) -> axum::response::Response {
        let (status, error_message) = match self {
            Self::InvalidCredentialsError => (StatusCode::UNAUTHORIZED, "Invalid credentials"),
            Self::UnknownError => (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error"),
        };
        (status, Json(error_message)).into_response()
    }
}

pub fn init_router(state: AppState) -> Router {
    Router::new()
        .nest(
            "/api/v1",
            Router::new()
                .route("/health", get(health_handler))
                .route("/validate-token", get(validate_token_handler))
                .route("/me", get(me_handler))
                .route("/login", post(login_handler))
                .route("/logout", post(logout_handler))
                .route("/oauth/token", post(oauth_token_handler))
                .route("/oauth/introspect", post(oauth_introspect_handler)),
        )
        .layer(TraceLayer::new_for_http().on_response(
            trace::DefaultOnResponse::new().latency_unit(tower_http::LatencyUnit::Micros),
        ))
        .layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ))
        .layer(CompressionLayer::new())
        .layer(CookieManagerLayer::new())
        .with_state(state)
}

async fn health_handler(State(state): State<AppState>) -> Result<Json<HealthCheck>, DomainError> {
    Ok(Json(HealthCheck {
        boot_time: state.config.boot_time,
        api_version: state.config.api_version,
    }))
}

async fn validate_token_handler(
    Extension(auth): Extension<Option<Auth>>,
) -> Result<Json<TokenValidation>, DomainError> {
    match auth {
        Some(_) => Ok(Json(TokenValidation { valid: true })),
        None => Ok(Json(TokenValidation { valid: false })),
    }
}

async fn me_handler(Extension(auth): Extension<Option<Auth>>) -> Json<UserSettings> {
    Json(UserSettings { auth })
}

async fn login_handler(
    cookies: Cookies,
    State(state): State<AppState>,
    Json(input): Json<LoginInput>,
) -> Result<Json<User>, DomainError> {
    let user = login_user(state.db.clone(), input).await?;
    handle_valid_user(state, user, cookies).await
}

async fn logout_handler(cookies: Cookies, State(state): State<AppState>) -> StatusCode {
    cookies.remove(session_cookie(
        state.config.auth.cookie_name.clone(),
        String::new(),
        &state.config.env,
    ));
    StatusCode::NO_CONTENT
}

async fn oauth_token_handler(
    State(state): State<AppState>,
    Json(input): Json<TokenRequest>,
) -> Result<Json<TokenResponse>, DomainError> {
    let token = issue_access_token(&state.db, input).await?;
    Ok(Json(token))
}

async fn oauth_introspect_handler(
    State(state): State<AppState>,
    Json(input): Json<IntrospectRequest>,
) -> Result<Json<Introspection>, DomainError> {
    let introspection = introspect_access_token(&state.db, input).await?;
    Ok(Json(introspection))
}

async fn handle_valid_user(
    state: AppState,
    user: User,
    cookies: Cookies,
) -> Result<Json<User>, DomainError> {
    let auth_token = create_auth_token(&state.db, user.clone())
        .await
        .map_err(|err| {
            error!("Encountered unexpected database error: {:?}", err);
            DomainError::UnknownError
        })?;
    let token = create_jwt_token(
        user.clone(),
        auth_token.clone(),
        state.config.auth.secret.clone(),
    )?;

    cookies.add(session_cookie(
        state.config.auth.cookie_name.clone(),
        token,
        &state.config.env,
    ));
    Ok(Json(user))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{AuthConfig, Environment};
    use crate::database::connection::create_connection_pool;
    use axum::body::Body;
    use axum::http::{header, Request, StatusCode};
    use http_body_util::BodyExt;
    use tower::ServiceExt;

    fn test_state() -> AppState {
        AppState {
            db: create_connection_pool("postgres://nrdrm:nrdrm@localhost:5433/identity".into()),
            config: Config {
                env: Environment::Dev,
                port: "8081".into(),
                database_url: "postgres://nrdrm:nrdrm@localhost:5433/identity".into(),
                log_level: "info".into(),
                auth: AuthConfig {
                    secret: "test-secret".into(),
                    cookie_name: "nrdrm-login".into(),
                },
                boot_time: "2026-11-07T00:00:00Z".into(),
                api_version: "test".into(),
            },
        }
    }

    #[tokio::test]
    async fn logout_clears_the_session_cookie() {
        let response = init_router(test_state())
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/v1/logout")
                    .header(header::COOKIE, "nrdrm-login=session")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::NO_CONTENT);
        let set_cookie = response
            .headers()
            .get(header::SET_COOKIE)
            .unwrap()
            .to_str()
            .unwrap();
        assert!(set_cookie.starts_with("nrdrm-login="));
        assert!(set_cookie.contains("Max-Age=0"));
        assert!(set_cookie.contains("Path=/"));
        assert!(set_cookie.contains("HttpOnly"));
        let body = response.into_body().collect().await.unwrap().to_bytes();
        assert!(body.is_empty());
    }
}
