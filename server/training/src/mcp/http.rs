//! `/api/mcp` and the protected-resource document.
//!
//! The gateway checks the bearer token and forwards the caller's email.
//! This service allows the request only when that email is the owner's.

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

use super::tools::TrainingTools;

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
        owner_email: config.training_owner_email.clone(),
        allowed_origins: config.mcp_allowed_origins.clone(),
    }
}

#[derive(Clone)]
pub(crate) struct Guard<S> {
    inner: S,
    owner_email: String,
    allowed_origins: Vec<String>,
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
        let owner_email = self.owner_email.clone();
        let post = req.method() == Method::POST;
        let origin_ok = origin_allowed(req.headers(), &self.allowed_origins);
        let email = caller_email(req.headers());
        Box::pin(async move {
            if !post {
                return Ok(method_not_allowed());
            }
            if !origin_ok {
                return Ok(forbidden());
            }
            let Some(email) = email else {
                return Ok(unauthorized());
            };
            if email != owner_email {
                return Ok(forbidden());
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

fn caller_email(headers: &HeaderMap) -> Option<String> {
    let value = headers.get("x-nrdrm-email")?.to_str().ok()?;
    let email = value.trim();
    if email.is_empty() {
        None
    } else {
        Some(email.to_string())
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

fn unauthorized() -> Response {
    (
        StatusCode::UNAUTHORIZED,
        [(
            header::CONTENT_TYPE,
            HeaderValue::from_static("text/plain; charset=utf-8"),
        )],
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
