use axum::{
  body::Body, extract::State, http::Request, middleware::Next, response::Response
};

use tower_cookies::Cookies;

use crate::domain::{jwt::decode_jwt_token, model::Auth};

use super::main::AppState;

pub async fn auth_middleware(
  cookies: Cookies,
  State(state): State<AppState>,
  mut req: Request<Body>,
  next: Next,
) -> Response {
  let auth = cookies
    .get(&state.config.auth.cookie_name)
    .and_then(|cookie| {
        decode_jwt_token(cookie.value(), state.config.auth.secret.clone())
            .map(|token| Auth { user_id: token.user_id })
            .ok()
    });

  req.extensions_mut().insert(auth);

  next.run(req).await
}