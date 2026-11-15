use std::collections::HashMap;

use axum::body::Bytes;
use axum::extract::State;
use axum::http::{header, HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde::Serialize;

use crate::domain::oauth::{issue_access_token, TokenRequest};
use crate::domain::token::{authorization_server_metadata, exchange_form, TokenError};

use super::main::AppState;

#[derive(Serialize)]
struct OAuthError<'a> {
    error: &'a str,
}

pub async fn oauth_token(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    match media_type(&headers).as_deref() {
        Some("application/json") => json_client_credentials(&state, &body).await,
        Some("application/x-www-form-urlencoded") => form_token(&state, &body).await,
        _ => (
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
            "Expected request with `Content-Type: application/json` or `Content-Type: application/x-www-form-urlencoded`",
        )
            .into_response(),
    }
}

pub async fn oauth_authorization_server_metadata(State(state): State<AppState>) -> Response {
    match authorization_server_metadata(&state.config.oauth_issuer) {
        Ok(metadata) => Json(metadata).into_response(),
        Err(()) => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

async fn json_client_credentials(state: &AppState, body: &Bytes) -> Response {
    let input = match serde_json::from_slice::<TokenRequest>(body) {
        Ok(input) => input,
        Err(err) if err.is_data() => {
            return (
                StatusCode::UNPROCESSABLE_ENTITY,
                format!("Failed to deserialize the JSON body into the target type: {err}"),
            )
                .into_response();
        }
        Err(err) => {
            return (
                StatusCode::UNPROCESSABLE_ENTITY,
                format!("Failed to parse the request body as JSON: {err}"),
            )
                .into_response();
        }
    };
    match issue_access_token(&state.db, input).await {
        Ok(token) => token_response(token),
        Err(err) => err.into_response(),
    }
}

async fn form_token(state: &AppState, body: &Bytes) -> Response {
    let fields: HashMap<String, String> = url::form_urlencoded::parse(body).into_owned().collect();
    match exchange_form(&state.db, &fields).await {
        Ok(token) => token_response(token),
        Err(err) => token_error(err),
    }
}

fn token_response(token: crate::domain::oauth::TokenResponse) -> Response {
    (
        StatusCode::OK,
        [
            (header::CACHE_CONTROL, "no-store"),
            (header::PRAGMA, "no-cache"),
        ],
        Json(token),
    )
        .into_response()
}

fn token_error(err: TokenError) -> Response {
    let (status, error) = match err {
        TokenError::InvalidRequest => (StatusCode::BAD_REQUEST, "invalid_request"),
        TokenError::InvalidClient => (StatusCode::UNAUTHORIZED, "invalid_client"),
        TokenError::InvalidGrant => (StatusCode::BAD_REQUEST, "invalid_grant"),
        TokenError::UnsupportedGrant => (StatusCode::BAD_REQUEST, "unsupported_grant_type"),
        TokenError::Unavailable => (StatusCode::INTERNAL_SERVER_ERROR, "server_error"),
    };
    (
        status,
        [
            (header::CACHE_CONTROL, "no-store"),
            (header::PRAGMA, "no-cache"),
        ],
        Json(OAuthError { error }),
    )
        .into_response()
}

fn media_type(headers: &HeaderMap) -> Option<String> {
    let value = headers.get(header::CONTENT_TYPE)?.to_str().ok()?;
    Some(value.split(';').next()?.trim().to_ascii_lowercase())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::access_token::find_access_token_by_hash;
    use crate::database::oauth_client::insert_client;
    use crate::database::refresh_token::RefreshToken;
    use crate::database::schema::{oauth_client, refresh_token, user_account};
    use crate::database::user_account::{create_user, find_user_by_email};
    use crate::domain::oauth::{hash_credential, new_client_credentials};
    use axum::body::Body;
    use axum::http::Request;
    use chrono::Utc;
    use diesel::prelude::*;
    use http_body_util::BodyExt;
    use tower::ServiceExt;
    use uuid::Uuid;

    const REDIRECT: &str = "cursor://anysphere.cursor-mcp/oauth/callback";
    const VERIFIER: &str = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    const CHALLENGE: &str = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";
    const RESOURCE: &str = "http://localhost:8080/training/mcp";
    const PASSWORD: &str = "correct horse";

    struct Approved {
        client_id: Uuid,
        user_id: Uuid,
        email: String,
        code: String,
    }

    fn app() -> (axum::Router, AppState) {
        let state = super::super::main::test_state();
        let router = super::super::main::init_router(state.clone());
        (router, state)
    }

    fn form_body(pairs: &[(&str, &str)]) -> String {
        let mut serializer = url::form_urlencoded::Serializer::new(String::new());
        for (key, value) in pairs {
            serializer.append_pair(key, value);
        }
        serializer.finish()
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

    fn code_from_location(location: &str) -> String {
        let url = url::Url::parse(location).unwrap();
        url.query_pairs()
            .find(|(key, _)| key == "code")
            .unwrap()
            .1
            .into_owned()
    }

    async fn register_cursor(app: &axum::Router) -> Uuid {
        let body = format!(
            r#"{{"client_name":"Cursor","redirect_uris":["{REDIRECT}"],"token_endpoint_auth_method":"none","grant_types":["authorization_code","refresh_token"],"response_types":["code"]}}"#
        );
        let response = send(
            app,
            "POST",
            "/api/v1/oauth/register",
            Some("application/json"),
            None,
            body,
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
        let json = read_json(response).await;
        Uuid::parse_str(json["client_id"].as_str().unwrap()).unwrap()
    }

    async fn create_account(state: &AppState) -> (String, Uuid) {
        let email = format!("token-{}@example.com", Uuid::new_v4());
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

    async fn approve(app: &axum::Router, state: &AppState) -> Approved {
        let client_id = register_cursor(app).await;
        let client_id_str = client_id.to_string();
        let (email, user_id) = create_account(state).await;
        let cookie = login_cookie(app, &email).await;
        let page = send(
            app,
            "GET",
            &format!(
                "/api/v1/oauth/authorize?{}",
                form_body(&[
                    ("client_id", client_id_str.as_str()),
                    ("redirect_uri", REDIRECT),
                    ("response_type", "code"),
                    ("code_challenge", CHALLENGE),
                    ("code_challenge_method", "S256"),
                    ("resource", RESOURCE),
                    ("state", "xyz"),
                    ("scope", "training"),
                ])
            ),
            None,
            Some(&cookie),
            String::new(),
        )
        .await;
        assert_eq!(page.status(), StatusCode::OK);
        let csrf = csrf_from(&read_text(page).await);
        let response = send(
            app,
            "POST",
            "/api/v1/oauth/authorize",
            Some("application/x-www-form-urlencoded"),
            Some(&cookie),
            form_body(&[
                ("action", "approve"),
                ("client_id", client_id_str.as_str()),
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
        Approved {
            client_id,
            user_id,
            email,
            code: code_from_location(&location),
        }
    }

    async fn exchange(
        app: &axum::Router,
        approved: &Approved,
        changes: &[(&str, &str)],
    ) -> Response {
        let mut pairs = vec![
            ("grant_type", "authorization_code".to_string()),
            ("code", approved.code.clone()),
            ("redirect_uri", REDIRECT.to_string()),
            ("client_id", approved.client_id.to_string()),
            ("code_verifier", VERIFIER.to_string()),
            ("resource", RESOURCE.to_string()),
        ];
        for (key, value) in changes {
            if let Some(slot) = pairs.iter_mut().find(|(name, _)| name == key) {
                slot.1 = (*value).to_string();
            }
        }
        send(
            app,
            "POST",
            "/api/v1/oauth/token",
            Some("application/x-www-form-urlencoded"),
            None,
            form_body(
                &pairs
                    .iter()
                    .map(|(key, value)| (*key, value.as_str()))
                    .collect::<Vec<_>>(),
            ),
        )
        .await
    }

    async fn refresh(
        app: &axum::Router,
        client_id: Uuid,
        refresh_token: &str,
        resource: &str,
    ) -> Response {
        let client_id = client_id.to_string();
        send(
            app,
            "POST",
            "/api/v1/oauth/token",
            Some("application/x-www-form-urlencoded"),
            None,
            form_body(&[
                ("grant_type", "refresh_token"),
                ("refresh_token", refresh_token),
                ("client_id", client_id.as_str()),
                ("resource", resource),
            ]),
        )
        .await
    }

    async fn introspect(app: &axum::Router, token: &str) -> serde_json::Value {
        let response = send(
            app,
            "POST",
            "/api/v1/oauth/introspect",
            Some("application/json"),
            None,
            format!(r#"{{"token":"{token}"}}"#),
        )
        .await;
        assert_eq!(response.status(), StatusCode::OK);
        read_json(response).await
    }

    async fn refresh_row(state: &AppState, raw: &str) -> RefreshToken {
        let token_hash = hash_credential(raw);
        let conn = state.db.get().await.unwrap();
        conn.interact(move |conn| {
            refresh_token::table
                .filter(refresh_token::token_hash.eq(token_hash))
                .select(RefreshToken::as_select())
                .first(conn)
        })
        .await
        .unwrap()
        .unwrap()
    }

    async fn family_rows(state: &AppState, family_id: Uuid) -> Vec<RefreshToken> {
        let conn = state.db.get().await.unwrap();
        conn.interact(move |conn| {
            refresh_token::table
                .filter(refresh_token::family_id.eq(family_id))
                .select(RefreshToken::as_select())
                .load(conn)
        })
        .await
        .unwrap()
        .unwrap()
    }

    async fn assert_invalid_grant(response: Response) {
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        let body = read_json(response).await;
        assert_eq!(body["error"], "invalid_grant");
    }

    #[tokio::test]
    async fn authorization_code_becomes_tokens() {
        let (app, state) = app();
        let approved = approve(&app, &state).await;
        let response = exchange(&app, &approved, &[]).await;
        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response.headers().get(header::CACHE_CONTROL).unwrap(),
            "no-store"
        );
        let body = read_json(response).await;
        assert_eq!(body.as_object().unwrap().len(), 5);
        let access_token = body["access_token"].as_str().unwrap().to_string();
        let refresh_token = body["refresh_token"].as_str().unwrap().to_string();
        assert_eq!(body["token_type"], "Bearer");
        assert_eq!(body["expires_in"], 3600);
        assert_eq!(body["scope"], "training");
        assert_ne!(access_token, refresh_token);

        let stored = find_access_token_by_hash(&state.db, hash_credential(&access_token))
            .await
            .unwrap();
        assert_eq!(stored.user_id, Some(approved.user_id));
        assert_eq!(stored.scope.as_deref(), Some("training"));
        assert_eq!(stored.audience, RESOURCE);
        assert_ne!(stored.token_hash, access_token);
        let ttl = (stored.expires_at - Utc::now()).num_seconds();
        assert!((3500..=3600).contains(&ttl), "ttl {ttl}");

        let introspection = introspect(&app, &access_token).await;
        assert_eq!(introspection["active"], true);
        assert_eq!(introspection["aud"], RESOURCE);
        assert_eq!(introspection["email"], approved.email);
        assert_eq!(introspection["sub"], approved.user_id.to_string());
        assert_eq!(introspection["scope"], "training");
        assert_eq!(introspection["client_name"], "Cursor");
        assert_eq!(introspection["client_id"], approved.client_id.to_string());
        let exp = introspection["exp"].as_i64().unwrap();
        let now = Utc::now().timestamp();
        assert!((now + 3500..=now + 3600).contains(&exp), "exp {exp}");

        let stored_refresh = refresh_row(&state, &refresh_token).await;
        let refresh_ttl = (stored_refresh.expires_at - Utc::now()).num_seconds();
        let thirty_days = 30 * 24 * 60 * 60;
        assert!(
            (thirty_days - 120..=thirty_days).contains(&refresh_ttl),
            "refresh ttl {refresh_ttl}"
        );

        cleanup(&state, approved.client_id, Some(approved.user_id)).await;
    }

    #[tokio::test]
    async fn reusing_a_code_fails() {
        let (app, state) = app();
        let approved = approve(&app, &state).await;
        let first = exchange(&app, &approved, &[]).await;
        assert_eq!(first.status(), StatusCode::OK);
        let issued = read_json(first).await;
        let access_token = issued["access_token"].as_str().unwrap().to_string();

        let second = exchange(&app, &approved, &[]).await;
        assert_invalid_grant(second).await;

        let introspection = introspect(&app, &access_token).await;
        assert_eq!(introspection["active"], true);
        cleanup(&state, approved.client_id, Some(approved.user_id)).await;
    }

    #[tokio::test]
    async fn wrong_verifier_fails() {
        let (app, state) = app();
        let approved = approve(&app, &state).await;
        let wrong = exchange(
            &app,
            &approved,
            &[(
                "code_verifier",
                "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXj",
            )],
        )
        .await;
        assert_invalid_grant(wrong).await;

        let retry = exchange(&app, &approved, &[]).await;
        assert_invalid_grant(retry).await;
        cleanup(&state, approved.client_id, Some(approved.user_id)).await;
    }

    #[tokio::test]
    async fn wrong_redirect_and_resource_fail() {
        let (app, state) = app();
        let approved = approve(&app, &state).await;
        let redirect = exchange(
            &app,
            &approved,
            &[("redirect_uri", "cursor://anysphere.cursor-mcp/oauth/other")],
        )
        .await;
        assert_invalid_grant(redirect).await;

        let again = approve(&app, &state).await;
        let resource = exchange(
            &app,
            &again,
            &[("resource", "http://localhost:8080/training/other")],
        )
        .await;
        assert_invalid_grant(resource).await;
        cleanup(&state, approved.client_id, Some(approved.user_id)).await;
        cleanup(&state, again.client_id, Some(again.user_id)).await;
    }

    #[tokio::test]
    async fn refresh_rotation_issues_a_new_pair() {
        let (app, state) = app();
        let approved = approve(&app, &state).await;
        let issued = read_json(exchange(&app, &approved, &[]).await).await;
        let first_refresh = issued["refresh_token"].as_str().unwrap().to_string();
        let first_access = issued["access_token"].as_str().unwrap().to_string();

        let response = refresh(&app, approved.client_id, &first_refresh, RESOURCE).await;
        assert_eq!(response.status(), StatusCode::OK);
        let rotated = read_json(response).await;
        let second_refresh = rotated["refresh_token"].as_str().unwrap().to_string();
        let second_access = rotated["access_token"].as_str().unwrap().to_string();
        assert_ne!(second_refresh, first_refresh);
        assert_ne!(second_access, first_access);
        assert_eq!(rotated["expires_in"], 3600);
        assert_eq!(rotated["scope"], "training");

        let introspection = introspect(&app, &second_access).await;
        assert_eq!(introspection["active"], true);
        assert_eq!(introspection["email"], approved.email);
        assert_eq!(introspection["aud"], RESOURCE);

        let first = refresh_row(&state, &first_refresh).await;
        let second = refresh_row(&state, &second_refresh).await;
        assert_eq!(first.family_id, second.family_id);
        assert!(first.revoked_at.is_some());
        assert_eq!(first.replaced_by, Some(second.id));
        assert!(second.revoked_at.is_none());
        assert!(second.replaced_by.is_none());
        let ttl = (second.expires_at - Utc::now()).num_seconds();
        let thirty_days = 30 * 24 * 60 * 60;
        assert!(
            (thirty_days - 120..=thirty_days).contains(&ttl),
            "ttl {ttl}"
        );

        cleanup(&state, approved.client_id, Some(approved.user_id)).await;
    }

    #[tokio::test]
    async fn reused_refresh_token_revokes_the_family() {
        let (app, state) = app();
        let approved = approve(&app, &state).await;
        let issued = read_json(exchange(&app, &approved, &[]).await).await;
        let first_refresh = issued["refresh_token"].as_str().unwrap().to_string();
        let rotated =
            read_json(refresh(&app, approved.client_id, &first_refresh, RESOURCE).await).await;
        let second_refresh = rotated["refresh_token"].as_str().unwrap().to_string();

        let reuse = refresh(&app, approved.client_id, &first_refresh, RESOURCE).await;
        assert_invalid_grant(reuse).await;

        let family_id = refresh_row(&state, &first_refresh).await.family_id;
        let rows = family_rows(&state, family_id).await;
        assert!(rows.len() >= 2);
        assert!(rows.iter().all(|row| row.revoked_at.is_some()));

        let child = refresh(&app, approved.client_id, &second_refresh, RESOURCE).await;
        assert_invalid_grant(child).await;
        cleanup(&state, approved.client_id, Some(approved.user_id)).await;
    }

    #[tokio::test]
    async fn refresh_for_a_different_resource_keeps_the_token() {
        let (app, state) = app();
        let approved = approve(&app, &state).await;
        let issued = read_json(exchange(&app, &approved, &[]).await).await;
        let refresh_token = issued["refresh_token"].as_str().unwrap().to_string();

        let wrong = refresh(
            &app,
            approved.client_id,
            &refresh_token,
            "http://localhost:8080/training/other",
        )
        .await;
        assert_invalid_grant(wrong).await;

        let response = refresh(&app, approved.client_id, &refresh_token, RESOURCE).await;
        assert_eq!(response.status(), StatusCode::OK);
        cleanup(&state, approved.client_id, Some(approved.user_id)).await;
    }

    #[tokio::test]
    async fn client_credentials_json_still_issues_a_bearer_token() {
        let (app, state) = app();
        let credentials = new_client_credentials();
        let name = format!("agents-{}", Uuid::new_v4());
        let client = insert_client(
            &state.db,
            name.clone(),
            credentials.secret_hash,
            "agents".into(),
        )
        .await
        .unwrap();
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/token",
            Some("application/json"),
            None,
            format!(
                r#"{{"grant_type":"client_credentials","client_id":"{}","client_secret":"{}","audience":"agents"}}"#,
                client.id, credentials.client_secret
            ),
        )
        .await;
        assert_eq!(response.status(), StatusCode::OK);
        let body = read_json(response).await;
        assert_eq!(body.as_object().unwrap().len(), 3);
        assert_eq!(body["token_type"], "Bearer");
        assert_eq!(body["expires_in"], 3600);
        let access_token = body["access_token"].as_str().unwrap();
        let introspection = introspect(&app, access_token).await;
        assert_eq!(introspection["active"], true);
        assert_eq!(introspection["aud"], "agents");
        assert_eq!(introspection["client_name"], name);
        assert!(introspection.get("email").is_none());
        assert!(introspection.get("sub").is_none());
        assert!(introspection.get("scope").is_none());

        let stored = find_access_token_by_hash(&state.db, hash_credential(access_token))
            .await
            .unwrap();
        assert!(stored.user_id.is_none());
        assert!(stored.scope.is_none());
        cleanup(&state, client.id, None).await;
    }

    #[tokio::test]
    async fn client_credentials_json_keeps_the_existing_error() {
        let (app, _) = app();
        let response = send(
            &app,
            "POST",
            "/api/v1/oauth/token",
            Some("application/json"),
            None,
            format!(
                r#"{{"grant_type":"client_credentials","client_id":"{}","client_secret":"nope","audience":"agents"}}"#,
                Uuid::new_v4()
            ),
        )
        .await;
        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
        let body = read_json(response).await;
        assert_eq!(body, serde_json::json!("Invalid credentials"));
    }

    #[tokio::test]
    async fn authorization_server_metadata_lists_the_grant_types() {
        let (app, _) = app();
        let response = send(
            &app,
            "GET",
            "/api/v1/oauth-authorization-server/identity",
            None,
            None,
            String::new(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::OK);
        let body = read_json(response).await;
        assert_eq!(body["issuer"], "http://localhost:8080/identity");
        assert_eq!(
            body["authorization_endpoint"],
            "http://localhost:8080/identity/oauth/authorize"
        );
        assert_eq!(
            body["token_endpoint"],
            "http://localhost:8080/identity/oauth/token"
        );
        assert_eq!(
            body["registration_endpoint"],
            "http://localhost:8080/identity/oauth/register"
        );
        assert_eq!(
            body["code_challenge_methods_supported"],
            serde_json::json!(["S256"])
        );
        assert_eq!(
            body["grant_types_supported"],
            serde_json::json!(["authorization_code", "refresh_token", "client_credentials"])
        );
        assert_eq!(
            body["token_endpoint_auth_methods_supported"],
            serde_json::json!(["none", "client_secret_post"])
        );
        assert_eq!(body["scopes_supported"], serde_json::json!(["training"]));
    }
}
