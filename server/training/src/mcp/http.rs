//! `/api/mcp` and the protected-resource document a client reads from a 401.

use std::convert::Infallible;
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll};

use axum::body::Body;
use axum::http::{header, HeaderMap, HeaderValue, Method, Request, StatusCode};
use axum::response::{IntoResponse, Response};
use deadpool_diesel::postgres::Pool;
use rmcp::transport::streamable_http_server::session::never::NeverSessionManager;
use rmcp::transport::{StreamableHttpServerConfig, StreamableHttpService};
use serde::Serialize;
use tower::Service;

use crate::clock::Clock;
use crate::config::Config;

use super::auth::{TokenError, TokenVerifier};
use super::tools::TrainingTools;

pub(crate) fn protected_resource_url(resource: &str) -> String {
    let resource = resource.trim_end_matches('/');
    let base = resource.strip_suffix("/mcp").unwrap_or(resource);
    format!("{base}/oauth-protected-resource")
}

#[derive(Debug, Serialize, PartialEq, Eq)]
pub(crate) struct ProtectedResource {
    pub resource: String,
    pub authorization_servers: Vec<String>,
    pub scopes_supported: Vec<&'static str>,
    pub bearer_methods_supported: Vec<&'static str>,
}

pub(crate) fn protected_resource(config: &Config) -> ProtectedResource {
    ProtectedResource {
        resource: config.mcp_resource_url.clone(),
        authorization_servers: vec![config.authorization_server_url.clone()],
        scopes_supported: vec!["training"],
        bearer_methods_supported: vec!["header"],
    }
}

pub(crate) fn service(
    db: Pool,
    clock: Arc<dyn Clock>,
    tokens: Arc<dyn TokenVerifier>,
    config: &Config,
) -> Guard<StreamableHttpService<TrainingTools, NeverSessionManager>> {
    let inner = StreamableHttpService::new(
        move || Ok(TrainingTools::new(db.clone(), clock.clone())),
        Arc::new(NeverSessionManager::default()),
        StreamableHttpServerConfig::default()
            .with_legacy_session_mode(false)
            .with_json_response(true)
            .disable_allowed_hosts()
            .disable_allowed_origins(),
    );
    Guard {
        inner,
        tokens,
        owner_email: config.training_owner_email.clone(),
        allowed_origins: config.mcp_allowed_origins.clone(),
        challenge: challenge(&config.mcp_resource_url),
    }
}

fn challenge(resource_url: &str) -> HeaderValue {
    let metadata = protected_resource_url(resource_url);
    HeaderValue::from_str(&format!(
        "Bearer resource_metadata=\"{metadata}\", scope=\"training\""
    ))
    .expect("protected resource URL is a header value")
}

#[derive(Clone)]
pub(crate) struct Guard<S> {
    inner: S,
    tokens: Arc<dyn TokenVerifier>,
    owner_email: String,
    allowed_origins: Vec<String>,
    challenge: HeaderValue,
}

impl<S> Service<Request<Body>> for Guard<S>
where
    S: Service<Request<Body>, Error = Infallible> + Clone + Send + 'static,
    S::Response: IntoResponse,
    S::Future: Send + 'static,
{
    type Response = Response;
    type Error = Infallible;
    type Future = Pin<Box<dyn Future<Output = Result<Response, Infallible>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Infallible>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, req: Request<Body>) -> Self::Future {
        let mut inner = self.inner.clone();
        let tokens = Arc::clone(&self.tokens);
        let owner_email = self.owner_email.clone();
        let challenge = self.challenge.clone();
        let post = req.method() == Method::POST;
        let origin_ok = origin_allowed(req.headers(), &self.allowed_origins);
        let token = bearer(req.headers()).map(str::to_string);
        Box::pin(async move {
            if !post {
                return Ok(method_not_allowed());
            }
            if !origin_ok {
                return Ok(forbidden());
            }
            let Some(token) = token else {
                return Ok(unauthorized(&challenge));
            };
            match tokens.verify(&token).await {
                Ok(caller) if caller.email == owner_email => {}
                Ok(_) => return Ok(forbidden()),
                Err(TokenError::Invalid) => return Ok(unauthorized(&challenge)),
                Err(TokenError::Unavailable) => return Ok(unavailable()),
            }
            let response = inner
                .call(req)
                .await
                .expect("the mcp endpoint does not fail the http service");
            Ok(response.into_response())
        })
    }
}

fn origin_allowed(headers: &HeaderMap, allowed: &[String]) -> bool {
    let Some(value) = headers.get(header::ORIGIN) else {
        return true;
    };
    let Ok(origin) = value.to_str() else {
        return false;
    };
    allowed.iter().any(|candidate| candidate == origin)
}

fn bearer(headers: &HeaderMap) -> Option<&str> {
    let value = headers.get(header::AUTHORIZATION)?.to_str().ok()?;
    let (scheme, token) = value.split_once(' ')?;
    if !scheme.eq_ignore_ascii_case("bearer") {
        return None;
    }
    let token = token.trim();
    if token.is_empty() {
        None
    } else {
        Some(token)
    }
}

fn method_not_allowed() -> Response {
    (
        StatusCode::METHOD_NOT_ALLOWED,
        [
            (header::ALLOW, HeaderValue::from_static("POST")),
            (
                header::CONTENT_TYPE,
                HeaderValue::from_static("text/plain; charset=utf-8"),
            ),
        ],
        "Method not allowed",
    )
        .into_response()
}

fn unauthorized(challenge: &HeaderValue) -> Response {
    (
        StatusCode::UNAUTHORIZED,
        [
            (header::WWW_AUTHENTICATE, challenge.clone()),
            (
                header::CONTENT_TYPE,
                HeaderValue::from_static("text/plain; charset=utf-8"),
            ),
        ],
        "Unauthorized",
    )
        .into_response()
}

fn forbidden() -> Response {
    (
        StatusCode::FORBIDDEN,
        [(
            header::CONTENT_TYPE,
            HeaderValue::from_static("text/plain; charset=utf-8"),
        )],
        "Forbidden",
    )
        .into_response()
}

fn unavailable() -> Response {
    (
        StatusCode::SERVICE_UNAVAILABLE,
        [(
            header::CONTENT_TYPE,
            HeaderValue::from_static("text/plain; charset=utf-8"),
        )],
        "The training log can't check this sign-in right now.",
    )
        .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_metadata_url_sits_beside_the_mcp_url() {
        assert_eq!(
            protected_resource_url("http://localhost:8080/training/mcp"),
            "http://localhost:8080/training/oauth-protected-resource"
        );
        assert_eq!(
            protected_resource_url("http://localhost:8080/training/mcp/"),
            "http://localhost:8080/training/oauth-protected-resource"
        );
    }
}
