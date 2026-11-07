use crate::config::Config;
use axum::{routing::get, Json, Router};
use deadpool_diesel::postgres::Pool;
use serde::{Deserialize, Serialize};
use tower_http::trace::{self, TraceLayer};

#[derive(Clone)]
pub struct AppState {
    pub db: Pool,
    pub config: Config,
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
struct Health {
    status: String,
}

pub fn init_router(state: AppState) -> Router {
    Router::new()
        .route("/api/health", get(health))
        .layer(TraceLayer::new_for_http().on_response(
            trace::DefaultOnResponse::new().latency_unit(tower_http::LatencyUnit::Micros),
        ))
        .with_state(state)
}

async fn health() -> Json<Health> {
    Json(Health {
        status: "ok".to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::connection::create_connection_pool;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use http_body_util::BodyExt;
    use tower::ServiceExt;

    fn test_state() -> AppState {
        let database_url = "postgres://nrdrm:nrdrm@localhost:5437/training".to_string();
        AppState {
            db: create_connection_pool(database_url.clone()),
            config: Config {
                port: "8082".to_string(),
                database_url,
                log_level: "info".to_string(),
            },
        }
    }

    #[tokio::test]
    async fn health_responds_ok_without_a_cookie() {
        let app = init_router(test_state());
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/api/health")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        assert!(response.headers().get("set-cookie").is_none());

        let body = response.into_body().collect().await.unwrap().to_bytes();
        let health: Health = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            health,
            Health {
                status: "ok".to_string(),
            }
        );
    }
}
