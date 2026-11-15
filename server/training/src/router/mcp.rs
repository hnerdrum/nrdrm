use std::sync::Arc;

use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};

use super::main::AppState;
use crate::mcp::http::{self, ProtectedResource};

pub(crate) fn routes(state: &AppState) -> Router<AppState> {
    Router::new()
        .route_service(
            "/api/mcp",
            http::service(state.db.clone(), Arc::clone(&state.clock), &state.config),
        )
        .route("/api/oauth-protected-resource", get(metadata))
}

async fn metadata(State(state): State<AppState>) -> Json<ProtectedResource> {
    Json(http::protected_resource(&state.config))
}

#[cfg(test)]
mod tests {
    use axum::body::Body;
    use axum::http::{header, HeaderMap, Request, StatusCode};
    use http_body_util::BodyExt;
    use serde_json::{json, Value};
    use tower::ServiceExt;
    use uuid::Uuid;

    use super::super::main::{init_router, test_state};

    const OWNER: &str = "ada@example.com";
    const FROM: &str = "2411-01-25";
    const TO: &str = "2411-02-15";
    const ON_DATE: &str = "2411-02-02";

    fn app() -> axum::Router {
        init_router(test_state())
    }

    async fn send(
        app: &axum::Router,
        method: &str,
        uri: &str,
        email: Option<&str>,
        origin: Option<&str>,
        body: Option<&str>,
    ) -> (StatusCode, HeaderMap, Vec<u8>) {
        let mut builder = Request::builder()
            .method(method)
            .uri(uri)
            .header(header::HOST, "localhost");
        if body.is_some() {
            builder = builder
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::ACCEPT, "application/json, text/event-stream");
        }
        if let Some(email) = email {
            builder = builder.header("x-nrdrm-email", email);
        }
        if let Some(origin) = origin {
            builder = builder.header(header::ORIGIN, origin);
        }
        let response = app
            .clone()
            .oneshot(
                builder
                    .body(match body {
                        Some(body) => Body::from(body.to_string()),
                        None => Body::empty(),
                    })
                    .unwrap(),
            )
            .await
            .unwrap();
        let status = response.status();
        let headers = response.headers().clone();
        let bytes = response.into_body().collect().await.unwrap().to_bytes();
        (status, headers, bytes.to_vec())
    }

    fn parse(bytes: &[u8]) -> Value {
        serde_json::from_slice(bytes)
            .unwrap_or_else(|err| panic!("{err}: {}", String::from_utf8_lossy(bytes)))
    }

    fn rpc(id: u64, method: &str, params: Value) -> String {
        json!({
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        })
        .to_string()
    }

    fn initialize() -> String {
        rpc(
            1,
            "initialize",
            json!({
                "protocolVersion": "2025-03-26",
                "capabilities": {},
                "clientInfo": { "name": "test", "version": "0.0.0" }
            }),
        )
    }

    async fn tool(app: &axum::Router, id: u64, name: &str, arguments: Value) -> Value {
        let (status, _, bytes) = send(
            app,
            "POST",
            "/api/mcp",
            Some(OWNER),
            None,
            Some(&rpc(
                id,
                "tools/call",
                json!({ "name": name, "arguments": arguments }),
            )),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let body = parse(&bytes);
        assert!(
            body.get("error").is_none(),
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        body
    }

    async fn clear(app: &axum::Router) {
        let (status, _, bytes) = send(
            app,
            "GET",
            &format!("/api/sessions?from={FROM}&to={TO}"),
            None,
            None,
            None,
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let sessions: Vec<Value> = serde_json::from_slice(&bytes).unwrap();
        for session in sessions {
            let id = session["id"].as_str().unwrap();
            let (status, _, _) = send(
                app,
                "DELETE",
                &format!("/api/sessions/{id}"),
                None,
                None,
                None,
            )
            .await;
            assert_eq!(status, StatusCode::NO_CONTENT);
        }
    }

    #[tokio::test]
    async fn a_missing_email_is_unauthorized() {
        let (status, headers, bytes) =
            send(&app(), "POST", "/api/mcp", None, None, Some(&initialize())).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert!(headers.get(header::WWW_AUTHENTICATE).is_none());
        assert_eq!(bytes, b"Unauthorized");
    }

    #[tokio::test]
    async fn a_bearer_token_is_not_a_sign_in() {
        let app = app();
        let request = Request::builder()
            .method("POST")
            .uri("/api/mcp")
            .header(header::HOST, "localhost")
            .header(header::CONTENT_TYPE, "application/json")
            .header(header::ACCEPT, "application/json, text/event-stream")
            .header(header::AUTHORIZATION, "Bearer owner")
            .body(Body::from(initialize()))
            .unwrap();
        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
        assert!(response.headers().get(header::WWW_AUTHENTICATE).is_none());
    }

    #[tokio::test]
    async fn a_different_email_is_forbidden() {
        let (status, headers, _) = send(
            &app(),
            "POST",
            "/api/mcp",
            Some("other@example.com"),
            None,
            Some(&initialize()),
        )
        .await;
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert!(headers.get(header::WWW_AUTHENTICATE).is_none());
    }

    #[tokio::test]
    async fn an_origin_that_is_not_allowed_is_forbidden() {
        let (status, headers, _) = send(
            &app(),
            "POST",
            "/api/mcp",
            Some(OWNER),
            Some("http://evil.example"),
            Some(&initialize()),
        )
        .await;
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert!(headers.get(header::WWW_AUTHENTICATE).is_none());
    }

    #[tokio::test]
    async fn an_allowed_origin_can_initialize() {
        let (status, _, bytes) = send(
            &app(),
            "POST",
            "/api/mcp",
            Some(OWNER),
            Some("http://localhost:3000"),
            Some(&initialize()),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let body = parse(&bytes);
        assert_eq!(body["result"]["protocolVersion"], "2025-03-26");
        assert!(body["result"]["capabilities"]["tools"].is_object());
    }

    #[tokio::test]
    async fn the_tool_list_marks_week_read_only_and_delete_destructive() {
        let (status, _, bytes) = send(
            &app(),
            "POST",
            "/api/mcp",
            Some(OWNER),
            None,
            Some(&rpc(2, "tools/list", json!({}))),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let body = parse(&bytes);
        let tools = body["result"]["tools"].as_array().unwrap();
        let mut names: Vec<&str> = tools
            .iter()
            .map(|tool| tool["name"].as_str().unwrap())
            .collect();
        names.sort_unstable();
        assert_eq!(
            names,
            [
                "delete_session",
                "latest_session",
                "log_ride",
                "log_run",
                "log_ski",
                "log_strength",
                "update_session",
                "week",
            ]
        );
        let week = tools.iter().find(|tool| tool["name"] == "week").unwrap();
        assert_eq!(week["annotations"]["readOnlyHint"], true);
        let latest = tools
            .iter()
            .find(|tool| tool["name"] == "latest_session")
            .unwrap();
        assert_eq!(latest["annotations"]["readOnlyHint"], true);
        let delete = tools
            .iter()
            .find(|tool| tool["name"] == "delete_session")
            .unwrap();
        assert_eq!(delete["annotations"]["destructiveHint"], true);
        let log_run = tools.iter().find(|tool| tool["name"] == "log_run").unwrap();
        assert_eq!(log_run["annotations"]["destructiveHint"], false);
    }

    #[tokio::test]
    async fn a_logged_run_is_listed_updated_and_soft_deleted() {
        let state = test_state();
        let db = state.db.clone();
        let app = init_router(state);
        clear(&app).await;

        let logged = tool(
            &app,
            3,
            "log_run",
            json!({ "on_date": ON_DATE, "distance_km": 10, "minutes": 57 }),
        )
        .await;
        let session = &logged["result"]["structuredContent"];
        assert_eq!(
            session["text"],
            "Run on 2411-02-02, 10 km in 57 min, 5:42 /km."
        );
        let id = session["id"].as_str().unwrap().to_string();

        let (status, _, bytes) = send(
            &app,
            "GET",
            &format!("/api/sessions?from={FROM}&to={TO}"),
            None,
            None,
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let listed: Vec<Value> = serde_json::from_slice(&bytes).unwrap();
        let row = listed.iter().find(|row| row["id"] == id).unwrap();
        assert_eq!(row["onDate"], ON_DATE);
        assert_eq!(row["body"]["sport"], "run");
        assert_eq!(row["body"]["distance"], 10_000);
        assert_eq!(row["body"]["duration"], 3_420);

        let week = tool(&app, 4, "week", json!({ "on_date": ON_DATE })).await;
        let week = &week["result"]["structuredContent"];
        assert_eq!(week["run_minutes"], 57.0);
        assert_eq!(week["ride_minutes"], 0.0);
        assert!(week["sessions"]
            .as_array()
            .unwrap()
            .iter()
            .any(|session| session["id"] == id));

        let latest = tool(
            &app,
            5,
            "latest_session",
            json!({ "sport": "run", "through": ON_DATE }),
        )
        .await;
        assert_eq!(latest["result"]["structuredContent"]["session"]["id"], id);

        let updated = tool(
            &app,
            6,
            "update_session",
            json!({ "id": id, "minutes": 58 }),
        )
        .await;
        assert_eq!(
            updated["result"]["structuredContent"]["text"],
            "Run on 2411-02-02, 10 km in 58 min, 5:48 /km."
        );

        let (status, _, bytes) = send(
            &app,
            "GET",
            &format!("/api/sessions?from={FROM}&to={TO}"),
            None,
            None,
            None,
        )
        .await;
        let listed: Vec<Value> = serde_json::from_slice(&bytes).unwrap();
        let row = listed.iter().find(|row| row["id"] == id).unwrap();
        assert_eq!(status, StatusCode::OK);
        assert_eq!(row["body"]["distance"], 10_000);
        assert_eq!(row["body"]["duration"], 3_480);

        let deleted = tool(&app, 7, "delete_session", json!({ "id": id })).await;
        let text = deleted["result"]["structuredContent"]["text"]
            .as_str()
            .unwrap();
        assert!(text.starts_with("Deleted. Run on 2411-02-02"));

        let (status, _, _) = send(
            &app,
            "GET",
            &format!("/api/sessions/{id}"),
            None,
            None,
            None,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert!(soft_deleted(&db, Uuid::parse_str(&id).unwrap()).await);

        forget(&db, Uuid::parse_str(&id).unwrap()).await;
    }

    #[tokio::test]
    async fn a_domain_problem_is_a_tool_error() {
        let app = app();
        let (status, _, bytes) = send(
            &app,
            "POST",
            "/api/mcp",
            Some(OWNER),
            None,
            Some(&rpc(
                8,
                "tools/call",
                json!({
                    "name": "log_run",
                    "arguments": { "on_date": ON_DATE, "distance_km": -1, "minutes": 57 }
                }),
            )),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let body = parse(&bytes);
        assert!(body.get("error").is_none());
        assert_eq!(body["result"]["isError"], true);
        assert_eq!(
            body["result"]["content"][0]["text"],
            "A distance needs to be a number of kilometres"
        );
    }

    #[tokio::test]
    async fn the_protected_resource_document_names_the_log() {
        let (status, _, bytes) = send(
            &app(),
            "GET",
            "/api/oauth-protected-resource",
            None,
            None,
            None,
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let body = parse(&bytes);
        assert_eq!(body["resource"], "http://localhost:8080/training/mcp");
        assert_eq!(
            body["authorization_servers"],
            json!(["http://localhost:8080/identity"])
        );
        assert_eq!(body["scopes_supported"], json!(["training"]));
        assert_eq!(body["bearer_methods_supported"], json!(["header"]));
    }

    #[tokio::test]
    async fn only_post_is_allowed_on_the_mcp_path() {
        for method in ["GET", "DELETE"] {
            let (status, headers, _) = send(&app(), method, "/api/mcp", None, None, None).await;
            assert_eq!(status, StatusCode::METHOD_NOT_ALLOWED, "{method}");
            assert_eq!(headers.get(header::ALLOW).unwrap(), "POST");
        }
    }

    async fn soft_deleted(pool: &deadpool_diesel::postgres::Pool, id: Uuid) -> bool {
        use crate::database::schema::training_session as session;
        use diesel::prelude::*;
        pool.get()
            .await
            .expect("database connection")
            .interact(move |conn| {
                let deleted: Option<chrono::DateTime<chrono::Utc>> = session::table
                    .filter(session::id.eq(id))
                    .select(session::deleted_at)
                    .first(conn)?;
                Ok::<_, diesel::result::Error>(deleted.is_some())
            })
            .await
            .expect("query")
            .expect("row")
    }

    async fn forget(pool: &deadpool_diesel::postgres::Pool, id: Uuid) {
        use crate::database::schema::training_session as session;
        use diesel::prelude::*;
        pool.get()
            .await
            .expect("database connection")
            .interact(move |conn| {
                diesel::delete(session::table.filter(session::id.eq(id))).execute(conn)
            })
            .await
            .expect("query")
            .expect("delete");
    }
}
