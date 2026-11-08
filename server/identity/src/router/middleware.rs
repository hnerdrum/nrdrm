use axum::{body::Body, extract::State, http::Request, middleware::Next, response::Response};

use tower_cookies::cookie::SameSite;
use tower_cookies::{Cookie, Cookies};

use crate::config::Environment;
use crate::{
    database::{
        auth_token::{create_auth_token, find_auth_token_by_id, TokenStatus},
        user_account::find_user_by_id,
    },
    domain::{
        jwt::{create_jwt_token, decode_jwt_token},
        model::{from_db_user, Auth},
    },
};

use super::main::AppState;
use tracing::{info, warn};

/// `Secure` follows the environment so a local `http://localhost` login can store the cookie.
pub fn session_cookie(name: String, value: String, env: &Environment) -> Cookie<'static> {
    Cookie::build((name, value))
        .path("/")
        .http_only(true)
        .secure(matches!(env, Environment::Prod))
        .same_site(SameSite::Lax)
        .build()
}

pub async fn auth_middleware(
    cookies: Cookies,
    State(state): State<AppState>,
    mut req: Request<Body>,
    next: Next,
) -> Response {
    let auth = match cookies.get(&state.config.auth.cookie_name) {
        Some(cookie) => match decode_jwt_token(cookie.value(), state.config.auth.secret.clone()) {
            Ok(decoded) => check_token_validity(decoded, state.clone(), cookies.clone()).await,
            Err(err) => {
                info!("Invalid JWT token: {:?}", err);
                None
            }
        },
        None => {
            info!("No session cookie found");
            None
        }
    };

    req.extensions_mut().insert(auth);

    next.run(req).await
}

async fn check_token_validity(auth: Auth, state: AppState, cookies: Cookies) -> Option<Auth> {
    let token_id = auth.token_id;
    let auth_token = match find_auth_token_by_id(&state.db, token_id).await {
        Ok(token) => token,
        Err(err) => {
            warn!("Token {token_id} not found in database: {:?}", err);
            return None;
        }
    };

    match auth_token.status {
        TokenStatus::Normal => Some(auth),
        TokenStatus::Withdrawn => {
            info!("Token {token_id} has been withdrawn, clearing cookie");
            cookies.remove(session_cookie(
                state.config.auth.cookie_name.clone(),
                String::new(),
                &state.config.env,
            ));
            None
        }
        TokenStatus::Expired => {
            info!("Token {token_id} expired, attempting refresh");
            refresh_auth(auth, state.clone(), cookies.clone()).await
        }
    }
}

async fn refresh_auth(auth: Auth, state: AppState, cookies: Cookies) -> Option<Auth> {
    let user = match find_user_by_id(&state.db, auth.user_id).await {
        Ok(user) => user,
        Err(err) => {
            warn!(
                "User {} not found when refreshing token: {:?}",
                auth.user_id, err
            );
            return None;
        }
    };

    let auth_token = match create_auth_token(&state.db, from_db_user(user.clone())).await {
        Ok(token) => token,
        Err(err) => {
            warn!("Failed to create auth token: {:?}", err);
            return None;
        }
    };

    let jwt = match create_jwt_token(
        from_db_user(user.clone()),
        auth_token.clone(),
        state.config.auth.secret.clone(),
    ) {
        Ok(token) => token,
        Err(err) => {
            warn!("Failed to create JWT token: {:?}", err);
            return None;
        }
    };

    cookies.add(session_cookie(
        state.config.auth.cookie_name.clone(),
        jwt,
        &state.config.env,
    ));

    Some(Auth {
        user_id: user.id,
        email: user.email,
        token_id: auth_token.id,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn session_cookie_is_http_only_and_lax_on_the_root_path() {
        let cookie = session_cookie("nrdrm-login".into(), "token".into(), &Environment::Dev);
        assert_eq!(cookie.name(), "nrdrm-login");
        assert_eq!(cookie.value(), "token");
        assert_eq!(cookie.path(), Some("/"));
        assert_eq!(cookie.http_only(), Some(true));
        assert_eq!(cookie.same_site(), Some(SameSite::Lax));
        assert_eq!(cookie.secure(), Some(false));
    }

    #[test]
    fn session_cookie_is_secure_in_production() {
        let cookie = session_cookie("nrdrm-login".into(), "token".into(), &Environment::Prod);
        assert_eq!(cookie.secure(), Some(true));
        assert_eq!(cookie.http_only(), Some(true));
    }
}
