use axum::body::Body;
use axum::extract::{Extension, Form, Json, Query, State};
use axum::http::{header, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use serde::{Deserialize, Serialize};
use tracing::{error, info};

use crate::config::Environment;
use crate::domain::authorize::{
    approve_page, authorize_params, csrf_matches, csrf_token, error_page, issue_authorization_code,
    login_page, redirect_target, AuthorizeFailure, AuthorizeInput, AuthorizeParams, RegisterError,
    RegistrationRequest,
};
use crate::domain::error::DomainError;
use crate::domain::model::{login_user, Auth, LoginInput};
use crate::domain::oauth::random_token;

use super::main::{start_session, AppState};
use super::middleware::session_cookie;

pub const OAUTH_BODY_LIMIT: usize = 8 * 1024;
const OAUTH_CSRF_COOKIE: &str = "nrdrm-oauth-csrf";
const MISSING_CSRF: &str = "This form is missing its security token. Start the sign-in again.";

#[derive(Deserialize)]
pub struct AuthorizeQuery {
    pub client_id: String,
    pub redirect_uri: String,
    pub response_type: String,
    #[serde(default)]
    pub code_challenge: Option<String>,
    #[serde(default)]
    pub code_challenge_method: Option<String>,
    pub resource: String,
    #[serde(default)]
    pub state: Option<String>,
    #[serde(default)]
    pub scope: Option<String>,
}

#[derive(Deserialize)]
pub struct AuthorizeForm {
    pub action: String,
    pub client_id: String,
    pub redirect_uri: String,
    pub response_type: String,
    pub code_challenge: String,
    pub code_challenge_method: String,
    pub resource: String,
    #[serde(default)]
    pub state: Option<String>,
    #[serde(default)]
    pub scope: Option<String>,
    #[serde(default)]
    pub csrf: Option<String>,
    #[serde(default)]
    pub email: Option<String>,
    #[serde(default)]
    pub password: Option<String>,
}

pub async fn oauth_register(
    State(state): State<AppState>,
    Json(body): Json<RegistrationRequest>,
) -> Response {
    match crate::domain::authorize::register_public_client(&state.db, body).await {
        Ok(registration) => {
            info!(
                "Registered public client {} ({})",
                registration.client_id, registration.client_name
            );
            (StatusCode::CREATED, Json(registration)).into_response()
        }
        Err(err) => register_error(err),
    }
}

pub async fn oauth_authorize_get(
    cookies: tower_cookies::Cookies,
    State(state): State<AppState>,
    Extension(auth): Extension<Option<Auth>>,
    Query(query): Query<AuthorizeQuery>,
) -> Response {
    let params = match authorize_params(
        &state.db,
        &state.config.oauth_resources,
        input_from_query(query),
    )
    .await
    {
        Ok(params) => params,
        Err(failure) => return failure_response(failure),
    };
    render_step(&cookies, &state, auth.as_ref(), &params, None)
}

pub async fn oauth_authorize_post(
    cookies: tower_cookies::Cookies,
    State(state): State<AppState>,
    Extension(auth): Extension<Option<Auth>>,
    Form(form): Form<AuthorizeForm>,
) -> Response {
    let Some(csrf) = form.csrf.clone().filter(|token| !token.is_empty()) else {
        return html_response(StatusCode::BAD_REQUEST, error_page(MISSING_CSRF));
    };
    let params = match authorize_params(
        &state.db,
        &state.config.oauth_resources,
        input_from_form(&form),
    )
    .await
    {
        Ok(params) => params,
        Err(failure) => return failure_response(failure),
    };
    let action = form.action.clone();

    match action.as_str() {
        "login" => login(&cookies, &state, &params, &csrf, form.email, form.password).await,
        "approve" => decide(&cookies, &state, auth.as_ref(), &params, &csrf, true).await,
        "deny" => decide(&cookies, &state, auth.as_ref(), &params, &csrf, false).await,
        _ => html_response(
            StatusCode::BAD_REQUEST,
            error_page("This form could not be read."),
        ),
    }
}

fn render_step(
    cookies: &tower_cookies::Cookies,
    state: &AppState,
    auth: Option<&Auth>,
    params: &AuthorizeParams,
    login_error: Option<&str>,
) -> Response {
    if auth.is_some() {
        let Some(cookie) = cookies.get(&state.config.auth.cookie_name) else {
            let csrf = issue_login_csrf(cookies, &state.config.auth.secret, &state.config.env);
            return html_response(StatusCode::OK, login_page(params, &csrf, login_error));
        };
        let csrf = csrf_token(cookie.value(), &state.config.auth.secret);
        return html_response(StatusCode::OK, approve_page(params, &csrf));
    }
    let csrf = issue_login_csrf(cookies, &state.config.auth.secret, &state.config.env);
    html_response(StatusCode::OK, login_page(params, &csrf, login_error))
}

async fn login(
    cookies: &tower_cookies::Cookies,
    state: &AppState,
    params: &AuthorizeParams,
    csrf: &str,
    email: Option<String>,
    password: Option<String>,
) -> Response {
    if !csrf_cookie_matches(cookies, OAUTH_CSRF_COOKIE, &state.config.auth.secret, csrf) {
        return html_response(StatusCode::BAD_REQUEST, error_page(MISSING_CSRF));
    }
    let (Some(email), Some(password)) = (email, password) else {
        return html_response(
            StatusCode::UNAUTHORIZED,
            login_page(params, csrf, Some("That email or password is wrong.")),
        );
    };
    let user = match login_user(state.db.clone(), LoginInput { email, password }).await {
        Ok(user) => user,
        Err(DomainError::InvalidCredentialsError) => {
            return html_response(
                StatusCode::UNAUTHORIZED,
                login_page(params, csrf, Some("That email or password is wrong.")),
            );
        }
        Err(DomainError::UnknownError) => {
            return html_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                error_page(AuthorizeFailure::Unavailable.message()),
            );
        }
    };
    let jwt = match start_session(state, user, cookies).await {
        Ok(jwt) => jwt,
        Err(_) => {
            return html_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                error_page(AuthorizeFailure::Unavailable.message()),
            );
        }
    };
    cookies.remove(session_cookie(
        OAUTH_CSRF_COOKIE.to_string(),
        String::new(),
        &state.config.env,
    ));
    let approve_csrf = csrf_token(&jwt, &state.config.auth.secret);
    html_response(StatusCode::OK, approve_page(params, &approve_csrf))
}

async fn decide(
    cookies: &tower_cookies::Cookies,
    state: &AppState,
    auth: Option<&Auth>,
    params: &AuthorizeParams,
    csrf: &str,
    approve: bool,
) -> Response {
    let Some(auth) = auth else {
        return html_response(
            StatusCode::BAD_REQUEST,
            error_page("Sign in before approving this application."),
        );
    };
    if !csrf_cookie_matches(
        cookies,
        &state.config.auth.cookie_name,
        &state.config.auth.secret,
        csrf,
    ) {
        return html_response(StatusCode::BAD_REQUEST, error_page(MISSING_CSRF));
    }

    if !approve {
        info!(
            "Denied client {} for user {}",
            params.client_id, auth.user_id
        );
        return redirect_response(&redirect_target(
            &params.redirect_uri,
            &deny_pairs(params.state.as_deref()),
        ));
    }

    let code = match issue_authorization_code(&state.db, params, auth.user_id).await {
        Ok(code) => code,
        Err(_) => {
            return html_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                error_page(AuthorizeFailure::Unavailable.message()),
            );
        }
    };
    info!(
        "Approved client {} for user {}",
        params.client_id, auth.user_id
    );
    redirect_response(&redirect_target(
        &params.redirect_uri,
        &approve_pairs(&code, params.state.as_deref()),
    ))
}

fn approve_pairs<'a>(code: &'a str, state: Option<&'a str>) -> Vec<(&'a str, &'a str)> {
    let mut pairs = vec![("code", code)];
    if let Some(state) = state {
        pairs.push(("state", state));
    }
    pairs
}

fn deny_pairs(state: Option<&str>) -> Vec<(&str, &str)> {
    let mut pairs = vec![("error", "access_denied")];
    if let Some(state) = state {
        pairs.push(("state", state));
    }
    pairs
}

fn csrf_cookie_matches(
    cookies: &tower_cookies::Cookies,
    name: &str,
    secret: &str,
    presented: &str,
) -> bool {
    cookies
        .get(name)
        .is_some_and(|cookie| csrf_matches(cookie.value(), secret, presented))
}

fn issue_login_csrf(cookies: &tower_cookies::Cookies, secret: &str, env: &Environment) -> String {
    let nonce = random_token();
    cookies.add(session_cookie(
        OAUTH_CSRF_COOKIE.to_string(),
        nonce.clone(),
        env,
    ));
    csrf_token(&nonce, secret)
}

fn input_from_query(query: AuthorizeQuery) -> AuthorizeInput {
    AuthorizeInput {
        client_id: query.client_id,
        redirect_uri: query.redirect_uri,
        response_type: query.response_type,
        code_challenge: query.code_challenge,
        code_challenge_method: query.code_challenge_method,
        resource: query.resource,
        state: query.state,
        scope: query.scope,
    }
}

fn input_from_form(form: &AuthorizeForm) -> AuthorizeInput {
    AuthorizeInput {
        client_id: form.client_id.clone(),
        redirect_uri: form.redirect_uri.clone(),
        response_type: form.response_type.clone(),
        code_challenge: Some(form.code_challenge.clone()),
        code_challenge_method: Some(form.code_challenge_method.clone()),
        resource: form.resource.clone(),
        state: form.state.clone(),
        scope: form.scope.clone(),
    }
}

fn failure_response(failure: AuthorizeFailure) -> Response {
    let status = match failure {
        AuthorizeFailure::Unavailable => {
            error!("Authorize request failed");
            StatusCode::INTERNAL_SERVER_ERROR
        }
        _ => {
            info!("Rejected authorize request: {failure:?}");
            StatusCode::BAD_REQUEST
        }
    };
    html_response(status, error_page(failure.message()))
}

fn register_error(err: RegisterError) -> Response {
    match err {
        RegisterError::InvalidRedirect => {
            info!("Rejected client registration: redirect URI");
            oauth_error(
                StatusCode::BAD_REQUEST,
                "invalid_redirect_uri",
                "Redirect URIs must be https, a loopback http address, or a custom scheme such as cursor://.",
            )
        }
        RegisterError::InvalidMetadata(description) => {
            info!("Rejected client registration: {description}");
            oauth_error(
                StatusCode::BAD_REQUEST,
                "invalid_client_metadata",
                description,
            )
        }
        RegisterError::Unavailable => {
            error!("Client registration failed");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json("Internal server error"),
            )
                .into_response()
        }
    }
}

#[derive(Serialize)]
struct OAuthErrorBody<'a> {
    error: &'a str,
    error_description: &'a str,
}

fn oauth_error(status: StatusCode, error: &str, description: &str) -> Response {
    (
        status,
        Json(OAuthErrorBody {
            error,
            error_description: description,
        }),
    )
        .into_response()
}

fn html_response(status: StatusCode, body: String) -> Response {
    (
        status,
        [
            (header::CONTENT_TYPE, "text/html; charset=utf-8"),
            (header::CONTENT_SECURITY_POLICY, "frame-ancestors 'none'"),
            (header::CACHE_CONTROL, "no-store"),
        ],
        body,
    )
        .into_response()
}

fn redirect_response(location: &str) -> Response {
    let Ok(location) = HeaderValue::from_str(location) else {
        return html_response(
            StatusCode::INTERNAL_SERVER_ERROR,
            error_page(AuthorizeFailure::Unavailable.message()),
        );
    };
    let mut response = Response::builder()
        .status(StatusCode::SEE_OTHER)
        .header(header::LOCATION, location)
        .header(header::REFERRER_POLICY, "no-referrer")
        .header(header::CACHE_CONTROL, "no-store")
        .body(Body::empty())
        .expect("redirect response");
    response.headers_mut().insert(
        header::CONTENT_SECURITY_POLICY,
        HeaderValue::from_static("frame-ancestors 'none'"),
    );
    response
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::authorization_code::AuthorizationCode;
    use crate::database::schema::{authorization_code, oauth_client, user_account};
    use crate::database::user_account::{create_user, find_user_by_email};
    use crate::domain::oauth::hash_credential;
    use axum::body::Body;
    use axum::http::Request;
    use chrono::Utc;
    use diesel::prelude::*;
    use http_body_util::BodyExt;
    use tower::ServiceExt;
    use uuid::Uuid;

    const REDIRECT: &str = "cursor://anysphere.cursor-mcp/oauth/callback";
    const CHALLENGE: &str = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";
    const RESOURCE: &str = "http://localhost:8080/training/mcp";
    const PASSWORD: &str = "correct horse";

    fn app() -> (axum::Router, AppState) {
        let state = super::super::main::test_state();
        let router = super::super::main::init_router(state.clone());
        (router, state)
    }

    fn cursor_registration() -> String {
        format!(
            r#"{{"client_name":"Cursor","redirect_uris":["{REDIRECT}"],"token_endpoint_auth_method":"none","grant_types":["authorization_code","refresh_token"],"response_types":["code"]}}"#
        )
    }

    fn form_body(pairs: &[(&str, &str)]) -> String {
        let mut serializer = url::form_urlencoded::Serializer::new(String::new());
        for (key, value) in pairs {
            serializer.append_pair(key, value);
        }
        serializer.finish()
    }

    fn authorize_uri(client_id: &str, changes: &[(&str, &str)]) -> String {
        let mut pairs = vec![
            ("client_id", client_id.to_string()),
            ("redirect_uri", REDIRECT.to_string()),
            ("response_type", "code".to_string()),
            ("code_challenge", CHALLENGE.to_string()),
            ("code_challenge_method", "S256".to_string()),
            ("resource", RESOURCE.to_string()),
            ("state", "xyz".to_string()),
            ("scope", "training".to_string()),
        ];
        for (key, value) in changes {
            if value.is_empty() {
                pairs.retain(|(name, _)| name != key);
            } else if let Some(slot) = pairs.iter_mut().find(|(name, _)| name == key) {
                slot.1 = (*value).to_string();
            } else {
                pairs.push((*key, (*value).to_string()));
            }
        }
        format!(
            "/api/v1/oauth/authorize?{}",
            form_body(
                &pairs
                    .iter()
                    .map(|(key, value)| (*key, value.as_str()))
                    .collect::<Vec<_>>()
            )
        )
    }

    async fn send(
        app: &axum::Router,
        method: &str,
        uri: &str,
        content_type: Option<&str>,
        cookie: Option<&str>,
        body: String,
    ) -> Response {
        let mut builder = Request::builder().method(method).uri(uri);
        if let Some(content_type) = content_type {
            builder = builder.header(header::CONTENT_TYPE, content_type);
        }
        if let Some(cookie) = cookie {
            builder = builder.header(header::COOKIE, cookie);
        }
        app.clone()
            .oneshot(builder.body(Body::from(body)).unwrap())
            .await
            .unwrap()
    }

    async fn read_json(response: Response) -> serde_json::Value {
        let bytes = response.into_body().collect().await.unwrap().to_bytes();
        serde_json::from_slice(&bytes).unwrap()
    }

    async fn read_text(response: Response) -> String {
        let bytes = response.into_body().collect().await.unwrap().to_bytes();
        String::from_utf8(bytes.to_vec()).unwrap()
    }

    fn cookie_pair(response: &Response, name: &str) -> Option<String> {
        response
            .headers()
            .get_all(header::SET_COOKIE)
            .iter()
            .find_map(|value| {
                let value = value.to_str().unwrap();
                let pair = value.split(';').next().unwrap();
                pair.starts_with(&format!("{name}="))
                    .then(|| pair.to_string())
            })
    }

    fn csrf_from(html: &str) -> String {
        let marker = "name=\"csrf\" value=\"";
        let start = html.find(marker).expect("csrf field") + marker.len();
        let end = html[start..].find('"').unwrap();
        html[start..start + end].to_string()
    }

    async fn register_cursor(app: &axum::Router) -> Uuid {
        let response = send(
            app,
            "POST",
            "/api/v1/oauth/register",
            Some("application/json"),
            None,
            cursor_registration(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
        let json = read_json(response).await;
        Uuid::parse_str(json["client_id"].as_str().unwrap()).unwrap()
    }

    async fn create_account(state: &AppState) -> (String, Uuid) {
        let email = format!("oauth-{}@example.com", Uuid::new_v4());
        let password_hash = bcrypt::hash(PASSWORD, 4).unwrap();
        create_user(&state.db, email.clone(), password_hash)
            .await
            .unwrap();
        let user = find_user_by_email(&state.db, email.clone()).await.unwrap();
        (email, user.id)
    }

    async fn login_cookie(app: &axum::Router, email: &str) -> String {
        let response = send(
            app,
            "POST",
            "/api/v1/login",
            Some("application/json"),
            None,
            format!(r#"{{"email":"{email}","password":"{PASSWORD}"}}"#),
        )
        .await;
        assert_eq!(response.status(), StatusCode::OK);
        cookie_pair(&response, "nrdrm-login").unwrap()
    }

    async fn cleanup(state: &AppState, client_id: Uuid, user_id: Option<Uuid>) {
        let conn = state.db.get().await.unwrap();
        conn.interact(move |conn| {
            diesel::delete(oauth_client::table.filter(oauth_client::id.eq(client_id)))
                .execute(conn)?;
            if let Some(user_id) = user_id {
                diesel::delete(user_account::table.filter(user_account::id.eq(user_id)))
                    .execute(conn)?;
            }
            Ok::<_, diesel::result::Error>(())
        })
        .await
        .unwrap()
        .unwrap();
    }

    async fn stored_code(state: &AppState, raw_code: &str) -> AuthorizationCode {
        let code_hash = hash_credential(raw_code);
        let conn = state.db.get().await.unwrap();
        conn.interact(move |conn| {
            authorization_code::table
                .filter(authorization_code::code_hash.eq(code_hash))
                .select(AuthorizationCode::as_select())
                .first(conn)
        })
        .await
        .unwrap()
        .unwrap()
    }

    #[tokio::test]
    async fn registers_a_public_client() {
        let (app, state) = app();
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/register",
            Some("application/json"),
            None,
            cursor_registration(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
        let json = read_json(response).await;
        assert!(json.get("client_secret").is_none());
        assert_eq!(json["token_endpoint_auth_method"], "none");
        assert_eq!(json["client_name"], "Cursor");
        assert_eq!(json["redirect_uris"][0], REDIRECT);
        assert_eq!(
            json["grant_types"],
            serde_json::json!(["authorization_code", "refresh_token"])
        );
        assert_eq!(json["response_types"], serde_json::json!(["code"]));
        let client_id = Uuid::parse_str(json["client_id"].as_str().unwrap()).unwrap();
        assert!(json["client_id_issued_at"].as_i64().unwrap() > 0);
        cleanup(&state, client_id, None).await;
    }

    #[tokio::test]
    async fn register_rejects_a_public_http_redirect() {
        let (app, _) = app();
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/register",
            Some("application/json"),
            None,
            r#"{"client_name":"Cursor","redirect_uris":["http://example.com/callback"],"token_endpoint_auth_method":"none"}"#.to_string(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        let json = read_json(response).await;
        assert_eq!(json["error"], "invalid_redirect_uri");
    }

    #[tokio::test]
    async fn register_rejects_a_client_secret() {
        let (app, _) = app();
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/register",
            Some("application/json"),
            None,
            r#"{"redirect_uris":["https://example.com/cb"],"token_endpoint_auth_method":"client_secret_basic"}"#.to_string(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        let json = read_json(response).await;
        assert_eq!(json["error"], "invalid_client_metadata");
    }

    #[tokio::test]
    async fn register_rejects_an_oversized_body() {
        let (app, _) = app();
        let body = format!(r#"{{"redirect_uris":["{}"]}}"#, "a".repeat(9_000));
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/register",
            Some("application/json"),
            None,
            body,
        )
        .await;
        assert_eq!(response.status(), StatusCode::PAYLOAD_TOO_LARGE);
    }

    #[tokio::test]
    async fn signed_in_visit_skips_the_password() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let (email, user_id) = create_account(&state).await;
        let cookie = login_cookie(&app, &email).await;
        let response = send(
            &app,
            "GET",
            &authorize_uri(&client_id.to_string(), &[]),
            None,
            Some(&cookie),
            String::new(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::OK);
        let csp = response
            .headers()
            .get(header::CONTENT_SECURITY_POLICY)
            .unwrap()
            .to_str()
            .unwrap();
        assert_eq!(csp, "frame-ancestors 'none'");
        let html = read_text(response).await;
        assert!(html.contains("Allow Cursor to read and write your training log"));
        assert!(!html.contains("name=\"password\""));
        cleanup(&state, client_id, Some(user_id)).await;
    }

    #[tokio::test]
    async fn approve_redirects_with_a_code() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let (email, user_id) = create_account(&state).await;
        let cookie = login_cookie(&app, &email).await;
        let page = send(
            &app,
            "GET",
            &authorize_uri(&client_id.to_string(), &[]),
            None,
            Some(&cookie),
            String::new(),
        )
        .await;
        assert_eq!(page.status(), StatusCode::OK);
        let html = read_text(page).await;
        let csrf = csrf_from(&html);
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/authorize",
            Some("application/x-www-form-urlencoded"),
            Some(&cookie),
            form_body(&[
                ("action", "approve"),
                ("client_id", &client_id.to_string()),
                ("redirect_uri", REDIRECT),
                ("response_type", "code"),
                ("code_challenge", CHALLENGE),
                ("code_challenge_method", "S256"),
                ("resource", RESOURCE),
                ("scope", "training"),
                ("state", "xyz"),
                ("csrf", &csrf),
            ]),
        )
        .await;
        assert_eq!(response.status(), StatusCode::SEE_OTHER);
        let location = response
            .headers()
            .get(header::LOCATION)
            .unwrap()
            .to_str()
            .unwrap()
            .to_string();
        assert!(location.starts_with(&format!("{REDIRECT}?")));
        let url = url::Url::parse(&location).unwrap();
        let query: std::collections::HashMap<_, _> = url.query_pairs().into_owned().collect();
        let code = query.get("code").unwrap();
        assert!(code.len() > 20);
        assert_eq!(query.get("state").unwrap(), "xyz");
        assert!(!query.contains_key("error"));

        let row = stored_code(&state, code).await;
        assert_eq!(row.code_hash, hash_credential(code));
        assert_ne!(row.code_hash, *code);
        assert_eq!(row.client_id, client_id);
        assert_eq!(row.user_id, user_id);
        assert_eq!(row.redirect_uri, REDIRECT);
        assert_eq!(row.code_challenge, CHALLENGE);
        assert_eq!(row.resource, RESOURCE);
        assert_eq!(row.scope, "training");
        assert!(row.used_at.is_none());
        let ttl = (row.expires_at - Utc::now()).num_seconds();
        assert!((40..=70).contains(&ttl), "ttl {ttl}");
        cleanup(&state, client_id, Some(user_id)).await;
    }

    #[tokio::test]
    async fn authorize_rejects_a_wrong_redirect_uri() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let response = send(
            &app,
            "GET",
            &authorize_uri(
                &client_id.to_string(),
                &[("redirect_uri", "https://evil.example/callback")],
            ),
            None,
            None,
            String::new(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert!(response.headers().get(header::LOCATION).is_none());
        let csp = response
            .headers()
            .get(header::CONTENT_SECURITY_POLICY)
            .unwrap()
            .to_str()
            .unwrap();
        assert_eq!(csp, "frame-ancestors 'none'");
        let html = read_text(response).await;
        assert!(html.contains("not registered for that application"));
        cleanup(&state, client_id, None).await;
    }

    #[tokio::test]
    async fn authorize_rejects_a_missing_pkce_challenge() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let response = send(
            &app,
            "GET",
            &authorize_uri(&client_id.to_string(), &[("code_challenge", "")]),
            None,
            None,
            String::new(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert!(response.headers().get(header::LOCATION).is_none());
        let html = read_text(response).await;
        assert!(html.contains("missing a PKCE code challenge"));
        cleanup(&state, client_id, None).await;
    }

    #[tokio::test]
    async fn authorize_rejects_an_unknown_resource() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let response = send(
            &app,
            "GET",
            &authorize_uri(
                &client_id.to_string(),
                &[("resource", "https://evil.example/mcp")],
            ),
            None,
            None,
            String::new(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert!(response.headers().get(header::LOCATION).is_none());
        let html = read_text(response).await;
        assert!(html.contains("resource that is not allowed"));
        cleanup(&state, client_id, None).await;
    }

    #[tokio::test]
    async fn approve_rejects_a_missing_csrf_token() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let (email, user_id) = create_account(&state).await;
        let cookie = login_cookie(&app, &email).await;
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/authorize",
            Some("application/x-www-form-urlencoded"),
            Some(&cookie),
            form_body(&[
                ("action", "approve"),
                ("client_id", &client_id.to_string()),
                ("redirect_uri", REDIRECT),
                ("response_type", "code"),
                ("code_challenge", CHALLENGE),
                ("code_challenge_method", "S256"),
                ("resource", RESOURCE),
                ("scope", "training"),
                ("state", "xyz"),
            ]),
        )
        .await;
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert!(response.headers().get(header::LOCATION).is_none());
        let html = read_text(response).await;
        assert!(html.contains("missing its security token"));
        cleanup(&state, client_id, Some(user_id)).await;
    }

    #[tokio::test]
    async fn login_on_the_page_sets_the_session_cookie() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let (email, user_id) = create_account(&state).await;
        let page = send(
            &app,
            "GET",
            &authorize_uri(&client_id.to_string(), &[]),
            None,
            None,
            String::new(),
        )
        .await;
        assert_eq!(page.status(), StatusCode::OK);
        let csrf_cookie = cookie_pair(&page, OAUTH_CSRF_COOKIE).unwrap();
        let html = read_text(page).await;
        assert!(html.contains("name=\"password\""));
        assert!(html.contains("Allow Cursor to read and write your training log"));
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/authorize",
            Some("application/x-www-form-urlencoded"),
            Some(&csrf_cookie),
            form_body(&[
                ("action", "login"),
                ("client_id", &client_id.to_string()),
                ("redirect_uri", REDIRECT),
                ("response_type", "code"),
                ("code_challenge", CHALLENGE),
                ("code_challenge_method", "S256"),
                ("resource", RESOURCE),
                ("scope", "training"),
                ("state", "xyz"),
                ("csrf", &csrf_from(&html)),
                ("email", &email),
                ("password", PASSWORD),
            ]),
        )
        .await;
        assert_eq!(response.status(), StatusCode::OK);
        let session = cookie_pair(&response, "nrdrm-login").unwrap();
        assert!(session.starts_with("nrdrm-login="));
        assert!(!session.contains("Max-Age=0"));
        let html = read_text(response).await;
        assert!(html.contains("Allow Cursor to read and write your training log"));
        assert!(!html.contains("name=\"password\""));
        cleanup(&state, client_id, Some(user_id)).await;
    }

    #[tokio::test]
    async fn deny_redirects_without_a_code() {
        let (app, state) = app();
        let client_id = register_cursor(&app).await;
        let (email, user_id) = create_account(&state).await;
        let cookie = login_cookie(&app, &email).await;
        let page = send(
            &app,
            "GET",
            &authorize_uri(&client_id.to_string(), &[]),
            None,
            Some(&cookie),
            String::new(),
        )
        .await;
        let html = read_text(page).await;
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/authorize",
            Some("application/x-www-form-urlencoded"),
            Some(&cookie),
            form_body(&[
                ("action", "deny"),
                ("client_id", &client_id.to_string()),
                ("redirect_uri", REDIRECT),
                ("response_type", "code"),
                ("code_challenge", CHALLENGE),
                ("code_challenge_method", "S256"),
                ("resource", RESOURCE),
                ("scope", "training"),
                ("state", "xyz"),
                ("csrf", &csrf_from(&html)),
            ]),
        )
        .await;
        assert_eq!(response.status(), StatusCode::SEE_OTHER);
        let location = response
            .headers()
            .get(header::LOCATION)
            .unwrap()
            .to_str()
            .unwrap();
        let url = url::Url::parse(location).unwrap();
        let query: std::collections::HashMap<_, _> = url.query_pairs().into_owned().collect();
        assert_eq!(query.get("error").unwrap(), "access_denied");
        assert_eq!(query.get("state").unwrap(), "xyz");
        assert!(!query.contains_key("code"));
        cleanup(&state, client_id, Some(user_id)).await;
    }
}
