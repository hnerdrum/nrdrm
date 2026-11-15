use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::{Duration, Utc};
use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use tracing::error;
use url::Url;
use uuid::Uuid;

use crate::database::{
    authorization_code::{insert_authorization_code, NewAuthorizationCode},
    connection::DBClient,
    error::DatabaseError,
    oauth_client::{find_client_by_id, insert_public_client},
};

use super::{
    error::DomainError,
    oauth::{hash_credential, random_token},
};

const TRAINING_SCOPE: &str = "training";
const CODE_TTL_SECONDS: i64 = 60;
const MAX_REDIRECT_URIS: usize = 8;
const MAX_CLIENT_NAME_CHARS: usize = 80;
const MAX_STATE_CHARS: usize = 2048;

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Deserialize)]
pub struct RegistrationRequest {
    pub redirect_uris: Vec<String>,
    #[serde(default)]
    pub token_endpoint_auth_method: Option<String>,
    #[serde(default)]
    pub grant_types: Vec<String>,
    #[serde(default)]
    pub response_types: Vec<String>,
    #[serde(default)]
    pub client_name: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct Registration {
    pub client_id: Uuid,
    pub client_id_issued_at: i64,
    pub client_name: String,
    pub redirect_uris: Vec<String>,
    pub token_endpoint_auth_method: String,
    pub grant_types: Vec<String>,
    pub response_types: Vec<String>,
}

#[derive(Debug)]
pub enum RegisterError {
    InvalidRedirect,
    InvalidMetadata(&'static str),
    Unavailable,
}

pub struct AuthorizeInput {
    pub client_id: String,
    pub redirect_uri: String,
    pub response_type: String,
    pub code_challenge: Option<String>,
    pub code_challenge_method: Option<String>,
    pub resource: String,
    pub state: Option<String>,
    pub scope: Option<String>,
}

pub struct AuthorizeParams {
    pub client_id: Uuid,
    pub client_name: String,
    pub redirect_uri: String,
    pub response_type: String,
    pub code_challenge: String,
    pub code_challenge_method: String,
    pub resource: String,
    pub state: Option<String>,
    pub scope: String,
}

#[derive(Debug)]
pub enum AuthorizeFailure {
    UnknownClient,
    RedirectMismatch,
    MissingPkce,
    BadPkceMethod,
    BadResponseType,
    UnknownResource,
    BadScope,
    BadState,
    Unavailable,
}

impl AuthorizeFailure {
    pub fn message(&self) -> &'static str {
        match self {
            Self::UnknownClient => "This application is not registered.",
            Self::RedirectMismatch => {
                "This redirect address is not registered for that application."
            }
            Self::MissingPkce => "This sign-in is missing a PKCE code challenge.",
            Self::BadPkceMethod => "This sign-in must use a PKCE S256 code challenge.",
            Self::BadResponseType => "This sign-in must use an authorization code.",
            Self::UnknownResource => {
                "This application is asking for a resource that is not allowed."
            }
            Self::BadScope => "This application is asking for a scope that is not allowed.",
            Self::BadState => "This sign-in state is not valid.",
            Self::Unavailable => "Something went wrong. Start the sign-in again.",
        }
    }
}

pub async fn register_public_client(
    db: &DBClient,
    request: RegistrationRequest,
) -> Result<Registration, RegisterError> {
    if let Some(method) = &request.token_endpoint_auth_method {
        if method != "none" {
            return Err(RegisterError::InvalidMetadata(
                "token_endpoint_auth_method must be none",
            ));
        }
    }
    let grant_types = grant_types(&request.grant_types)?;
    let response_types = response_types(&request.response_types)?;
    let client_name = client_name(request.client_name)?;
    if request.redirect_uris.is_empty() {
        return Err(RegisterError::InvalidMetadata("redirect_uris is required"));
    }
    if request.redirect_uris.len() > MAX_REDIRECT_URIS {
        return Err(RegisterError::InvalidMetadata(
            "redirect_uris has too many entries",
        ));
    }
    if request
        .redirect_uris
        .iter()
        .any(|uri| !redirect_uri_allowed(uri))
    {
        return Err(RegisterError::InvalidRedirect);
    }

    let client = insert_public_client(db, client_name.clone(), request.redirect_uris.clone())
        .await
        .map_err(|err| {
            error!("Encountered unexpected database error: {:?}", err);
            RegisterError::Unavailable
        })?;

    Ok(Registration {
        client_id: client.id,
        client_id_issued_at: client.created_at.timestamp(),
        client_name,
        redirect_uris: request.redirect_uris,
        token_endpoint_auth_method: "none".to_string(),
        grant_types,
        response_types,
    })
}

pub async fn authorize_params(
    db: &DBClient,
    allowed_resources: &[String],
    input: AuthorizeInput,
) -> Result<AuthorizeParams, AuthorizeFailure> {
    let client_id =
        Uuid::parse_str(input.client_id.trim()).map_err(|_| AuthorizeFailure::UnknownClient)?;
    let client = match find_client_by_id(db, client_id).await {
        Ok(client) => client,
        Err(DatabaseError::NotFoundError) => return Err(AuthorizeFailure::UnknownClient),
        Err(err) => {
            error!("Encountered unexpected database error: {:?}", err);
            return Err(AuthorizeFailure::Unavailable);
        }
    };

    if !redirect_uri_allowed(&input.redirect_uri)
        || !client
            .redirect_uris
            .iter()
            .flatten()
            .any(|uri| uri == &input.redirect_uri)
    {
        return Err(AuthorizeFailure::RedirectMismatch);
    }
    if input.response_type != "code" {
        return Err(AuthorizeFailure::BadResponseType);
    }

    let Some(code_challenge) = input
        .code_challenge
        .filter(|challenge| !challenge.is_empty())
    else {
        return Err(AuthorizeFailure::MissingPkce);
    };
    if !code_challenge_is_s256(&code_challenge) {
        return Err(AuthorizeFailure::BadPkceMethod);
    }
    if input.code_challenge_method.as_deref() != Some("S256") {
        return Err(AuthorizeFailure::BadPkceMethod);
    }
    if !allowed_resources
        .iter()
        .any(|resource| resource == &input.resource)
    {
        return Err(AuthorizeFailure::UnknownResource);
    }

    let scope = match input.scope.as_deref() {
        None => TRAINING_SCOPE.to_string(),
        Some(TRAINING_SCOPE) => TRAINING_SCOPE.to_string(),
        Some(_) => return Err(AuthorizeFailure::BadScope),
    };
    let state = match input.state {
        None => None,
        Some(state) if state.is_empty() => None,
        Some(state) if state.len() > MAX_STATE_CHARS || state.chars().any(|c| c.is_control()) => {
            return Err(AuthorizeFailure::BadState);
        }
        Some(state) => Some(state),
    };

    Ok(AuthorizeParams {
        client_id,
        client_name: client.name,
        redirect_uri: input.redirect_uri,
        response_type: input.response_type,
        code_challenge,
        code_challenge_method: "S256".to_string(),
        resource: input.resource,
        state,
        scope,
    })
}

pub async fn issue_authorization_code(
    db: &DBClient,
    params: &AuthorizeParams,
    user_id: Uuid,
) -> Result<String, DomainError> {
    let code = random_token();
    insert_authorization_code(
        db,
        NewAuthorizationCode {
            code_hash: hash_credential(&code),
            client_id: params.client_id,
            user_id,
            redirect_uri: params.redirect_uri.clone(),
            code_challenge: params.code_challenge.clone(),
            resource: params.resource.clone(),
            scope: params.scope.clone(),
            expires_at: Utc::now() + Duration::seconds(CODE_TTL_SECONDS),
        },
    )
    .await
    .map_err(|err| {
        error!("Encountered unexpected database error: {:?}", err);
        DomainError::UnknownError
    })?;
    Ok(code)
}

pub fn redirect_target(redirect_uri: &str, pairs: &[(&str, &str)]) -> String {
    let mut extra = url::form_urlencoded::Serializer::new(String::new());
    for (key, value) in pairs {
        extra.append_pair(key, value);
    }
    let extra = extra.finish();
    let separator = if redirect_uri.contains('?') { '&' } else { '?' };
    format!("{redirect_uri}{separator}{extra}")
}

/// The form token is an HMAC of the cookie value, so another site cannot submit it.
pub fn csrf_token(cookie_value: &str, secret: &str) -> String {
    let mut mac =
        HmacSha256::new_from_slice(secret.as_bytes()).expect("HMAC accepts any key length");
    mac.update(cookie_value.as_bytes());
    URL_SAFE_NO_PAD.encode(mac.finalize().into_bytes())
}

pub fn csrf_matches(cookie_value: &str, secret: &str, presented: &str) -> bool {
    let expected = csrf_token(cookie_value, secret);
    if expected.len() != presented.len() {
        return false;
    }
    let mut diff = 0u8;
    for (left, right) in expected.bytes().zip(presented.bytes()) {
        diff |= left ^ right;
    }
    diff == 0
}

pub fn login_page(params: &AuthorizeParams, csrf: &str, error: Option<&str>) -> String {
    let alert = error
        .map(|message| format!(r#"<p class="alert" role="alert">{}</p>"#, escape(message)))
        .unwrap_or_default();
    document(&format!(
        r#"<h1>{sentence}</h1>
<form method="post" action="authorize">
{fields}
<input type="hidden" name="action" value="login">
<label>Email
<input type="email" name="email" autocomplete="username" required>
</label>
<label>Password
<input type="password" name="password" autocomplete="current-password" required>
</label>
{alert}
<button type="submit">Log in</button>
</form>"#,
        sentence = allow_sentence(&params.client_name),
        fields = oauth_fields(params, csrf),
        alert = alert,
    ))
}

pub fn approve_page(params: &AuthorizeParams, csrf: &str) -> String {
    document(&format!(
        r#"<h1>{sentence}</h1>
<form method="post" action="authorize">
{fields}
<div class="actions">
<button type="submit" name="action" value="approve">Approve</button>
<button type="submit" class="secondary" name="action" value="deny">Deny</button>
</div>
</form>"#,
        sentence = allow_sentence(&params.client_name),
        fields = oauth_fields(params, csrf),
    ))
}

pub fn error_page(message: &str) -> String {
    document(&format!("<h1>{}</h1>", escape(message)))
}

fn allow_sentence(client_name: &str) -> String {
    format!(
        "Allow {} to read and write your training log",
        escape(client_name)
    )
}

fn oauth_fields(params: &AuthorizeParams, csrf: &str) -> String {
    let mut fields = vec![
        hidden("client_id", &params.client_id.to_string()),
        hidden("redirect_uri", &params.redirect_uri),
        hidden("response_type", &params.response_type),
        hidden("code_challenge", &params.code_challenge),
        hidden("code_challenge_method", &params.code_challenge_method),
        hidden("resource", &params.resource),
        hidden("scope", &params.scope),
        hidden("csrf", csrf),
    ];
    if let Some(state) = &params.state {
        fields.push(hidden("state", state));
    }
    fields.join("\n")
}

fn hidden(name: &str, value: &str) -> String {
    format!(
        r#"<input type="hidden" name="{}" value="{}">"#,
        escape(name),
        escape(value)
    )
}

fn escape(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for c in value.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            _ => out.push(c),
        }
    }
    out
}

fn document(body: &str) -> String {
    format!(
        r##"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<meta name="theme-color" content="#13121c">
<title>Training</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@300;400;500;600&display=swap" rel="stylesheet">
<style>{styles}</style>
</head>
<body>
<main>
<p class="mark">Training</p>
{body}
</main>
</body>
</html>
"##,
        styles = PAGE_STYLES,
    )
}

const PAGE_STYLES: &str = r#"
:root {
  color-scheme: dark;
  --bg: #13121c;
  --fg: #eceaf4;
  --muted: #9f9db5;
  --accent: #b4b9ff;
  --edge: #7e7c96;
  --field: #1a1927;
}
* { box-sizing: border-box; }
html { background: var(--bg); }
body {
  margin: 0;
  min-height: 100dvh;
  background: var(--bg);
  color: var(--fg);
  font-family: "Hanken Grotesk", system-ui, sans-serif;
  font-weight: 400;
  line-height: 1.55;
  padding: min(16vh, 7rem) 24px 48px;
}
main { width: min(100%, 26rem); margin: 0 auto; }
.mark {
  margin: 0 0 2rem;
  font-size: 1rem;
  font-weight: 600;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}
h1 {
  margin: 0 0 2rem;
  font-size: 2rem;
  font-weight: 400;
  letter-spacing: -0.03em;
  line-height: 1.25;
}
form { display: grid; gap: 1.5rem; }
label { display: grid; gap: 0.4rem; color: var(--muted); }
input {
  font: inherit;
  color: var(--fg);
  background: var(--field);
  border: 1px solid var(--edge);
  border-radius: 16px;
  min-height: 52px;
  padding: 0 16px;
}
input[type="hidden"] { display: none; }
input:hover { border-color: var(--muted); }
input:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 1px;
  border-color: var(--accent);
}
button {
  font: inherit;
  cursor: pointer;
  min-height: 52px;
  border-radius: 999px;
  border: 0;
  background: var(--fg);
  color: var(--bg);
  font-weight: 600;
}
button.secondary {
  background: transparent;
  color: var(--fg);
  border: 1px solid var(--edge);
  font-weight: 500;
}
button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.actions { display: grid; gap: 0.75rem; }
p.alert { margin: 0; font-weight: 500; }
"#;

fn grant_types(requested: &[String]) -> Result<Vec<String>, RegisterError> {
    if requested.is_empty() {
        return Ok(vec![
            "authorization_code".to_string(),
            "refresh_token".to_string(),
        ]);
    }
    if requested
        .iter()
        .any(|grant| grant != "authorization_code" && grant != "refresh_token")
    {
        return Err(RegisterError::InvalidMetadata(
            "grant_types must be authorization_code or refresh_token",
        ));
    }
    Ok(requested.to_vec())
}

fn response_types(requested: &[String]) -> Result<Vec<String>, RegisterError> {
    if requested.is_empty() {
        return Ok(vec!["code".to_string()]);
    }
    if requested.iter().any(|response| response != "code") {
        return Err(RegisterError::InvalidMetadata(
            "response_types must be code",
        ));
    }
    Ok(requested.to_vec())
}

fn client_name(raw: Option<String>) -> Result<String, RegisterError> {
    let Some(raw) = raw else {
        return Ok("this application".to_string());
    };
    let name = raw.trim();
    if name.is_empty() {
        return Ok("this application".to_string());
    }
    if name.chars().count() > MAX_CLIENT_NAME_CHARS || name.chars().any(|c| c.is_control()) {
        return Err(RegisterError::InvalidMetadata("client_name is not valid"));
    }
    Ok(name.to_string())
}

fn redirect_uri_allowed(raw: &str) -> bool {
    if raw.is_empty()
        || raw.len() > 512
        || !raw.is_ascii()
        || raw.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return false;
    }
    let Ok(url) = Url::parse(raw) else {
        return false;
    };
    if url.fragment().is_some() || !url.username().is_empty() || url.password().is_some() {
        return false;
    }
    match url.scheme() {
        "https" => url.host_str().is_some(),
        "http" => is_loopback(&url),
        scheme => custom_scheme_ok(scheme, &url),
    }
}

fn is_loopback(url: &Url) -> bool {
    match url.host() {
        Some(url::Host::Domain(domain)) => domain.eq_ignore_ascii_case("localhost"),
        Some(url::Host::Ipv4(ip)) => ip.is_loopback(),
        Some(url::Host::Ipv6(ip)) => ip.is_loopback(),
        None => false,
    }
}

fn custom_scheme_ok(scheme: &str, url: &Url) -> bool {
    const BANNED: &[&str] = &[
        "javascript",
        "data",
        "file",
        "blob",
        "about",
        "vbscript",
        "filesystem",
        "ws",
        "wss",
        "ftp",
        "ftps",
        "ssh",
        "tel",
        "sms",
        "mailto",
        "intent",
    ];
    if scheme.len() < 2 || BANNED.contains(&scheme) {
        return false;
    }
    let path = url.path();
    url.host_str().is_some() || (!path.is_empty() && path != "/")
}

fn code_challenge_is_s256(challenge: &str) -> bool {
    challenge.len() == 43
        && challenge
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn allows_https_loopback_and_custom_schemes() {
        assert!(redirect_uri_allowed("https://example.com/callback"));
        assert!(redirect_uri_allowed("http://127.0.0.1:33418/callback"));
        assert!(redirect_uri_allowed("http://localhost/callback"));
        assert!(redirect_uri_allowed("http://[::1]/callback"));
        assert!(redirect_uri_allowed(
            "cursor://anysphere.cursor-mcp/oauth/callback"
        ));
    }

    #[test]
    fn rejects_public_http_and_dangerous_schemes() {
        assert!(!redirect_uri_allowed("http://example.com/callback"));
        assert!(!redirect_uri_allowed("http://localhost.evil.com/callback"));
        assert!(!redirect_uri_allowed("javascript:alert(1)"));
        assert!(!redirect_uri_allowed("data:text/html,hi"));
        assert!(!redirect_uri_allowed("file:///etc/passwd"));
        assert!(!redirect_uri_allowed("https://example.com/callback#frag"));
        assert!(!redirect_uri_allowed(
            "https://user:pass@example.com/callback"
        ));
    }

    #[test]
    fn accepts_the_s256_challenge_shape() {
        assert!(code_challenge_is_s256(
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        ));
        assert!(!code_challenge_is_s256("plain"));
        assert!(!code_challenge_is_s256(""));
    }

    #[test]
    fn csrf_token_is_tied_to_the_cookie() {
        let token = csrf_token("cookie-a", "secret");
        assert_eq!(token, csrf_token("cookie-a", "secret"));
        assert!(csrf_matches("cookie-a", "secret", &token));
        assert!(!csrf_matches("cookie-b", "secret", &token));
        assert!(!csrf_matches("cookie-a", "secret", ""));
    }
}
