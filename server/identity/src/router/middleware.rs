use axum::{
  extract::State,
  middleware::Next,
  response::Response,
  http::Request,
  body::Body,
};

use tower_cookies::Cookies;

use crate::{database::auth_token::find_auth_token, domain::model::Auth};

use super::main::AppState;

pub async fn auth_middleware(
  cookies: Cookies,
  State(state): State<AppState>,
  mut req: Request<Body>,
  next: Next,
) -> Response {
  const AUTH_COOKIE_NAME: &str = "nrdrm-login";

  let auth = match cookies.get(AUTH_COOKIE_NAME) {
      Some(cookie) => {
          match find_auth_token(&state.db, cookie.value().to_owned()).await {
              Ok(token) => {
                  Some(Auth {
                      user_id: token.user_id,
                  })
              }
              Err(_) => None,
          }
      }
      None => None,
  };

  req.extensions_mut().insert(auth);

  next.run(req).await
}