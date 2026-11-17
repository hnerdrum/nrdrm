use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Json, Router};
use serde::Deserialize;
use uuid::Uuid;

use super::main::AppState;
use crate::database::preset::{self, Preset, PresetStoreError};
use crate::domain::preset::{body_rejection, preset_name};
use crate::domain::session::{SessionBody, Sport};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/presets", axum::routing::get(list).post(create))
        .route(
            "/api/presets/:id",
            axum::routing::get(read).put(update).delete(remove),
        )
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PresetInput {
    name: String,
    body: SessionBody,
}

impl PresetInput {
    /// The stored name and body, or why they can't be a preset.
    fn accepted(self) -> Result<(String, SessionBody), ApiError> {
        let name = preset_name(&self.name).map_err(ApiError::BadRequest)?;
        if let Some(message) = body_rejection(&self.body) {
            return Err(ApiError::BadRequest(message));
        }
        Ok((name, self.body))
    }
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct SportFilter {
    #[serde(default)]
    sport: Option<Sport>,
}

enum ApiError {
    NotFound,
    NameTaken,
    BadRequest(&'static str),
    Unavailable,
}

impl From<PresetStoreError> for ApiError {
    fn from(err: PresetStoreError) -> Self {
        match err {
            PresetStoreError::NotFound => Self::NotFound,
            PresetStoreError::NameTaken => Self::NameTaken,
            PresetStoreError::Connection | PresetStoreError::Unknown => Self::Unavailable,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        let (status, message) = match self {
            Self::NotFound => (StatusCode::NOT_FOUND, "Preset not found"),
            Self::NameTaken => (
                StatusCode::CONFLICT,
                "A preset with that name already exists",
            ),
            Self::BadRequest(message) => (StatusCode::BAD_REQUEST, message),
            Self::Unavailable => (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error"),
        };
        (status, Json(message)).into_response()
    }
}

async fn create(
    State(state): State<AppState>,
    Json(input): Json<PresetInput>,
) -> Result<(StatusCode, Json<Preset>), ApiError> {
    let (name, body) = input.accepted()?;
    let saved = preset::create(&state.db, name, body).await?;
    Ok((StatusCode::CREATED, Json(saved)))
}

async fn list(
    State(state): State<AppState>,
    Query(filter): Query<SportFilter>,
) -> Result<Json<Vec<Preset>>, ApiError> {
    let presets = preset::list(&state.db, filter.sport).await?;
    Ok(Json(presets))
}

async fn read(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Preset>, ApiError> {
    let saved = preset::find(&state.db, id).await?;
    Ok(Json(saved))
}

async fn update(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(input): Json<PresetInput>,
) -> Result<Json<Preset>, ApiError> {
    let (name, body) = input.accepted()?;
    let saved = preset::update(&state.db, id, name, body).await?;
    Ok(Json(saved))
}

async fn remove(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<StatusCode, ApiError> {
    preset::delete(&state.db, id).await?;
    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session::{Exercise, ExerciseSet, Interval};
    use crate::router::main::{init_router, test_state};
    use axum::body::Body;
    use axum::http::Request;
    use http_body_util::BodyExt;
    use serde::de::DeserializeOwned;
    use serde_json::json;
    use tower::ServiceExt;

    fn app() -> axum::Router {
        init_router(test_state())
    }

    /// A name no other test run uses, so tests share the database safely.
    fn unique(name: &str) -> String {
        format!("{name} {}", Uuid::new_v4().simple())
    }

    async fn call(
        app: &axum::Router,
        method: &str,
        uri: &str,
        body: Option<serde_json::Value>,
    ) -> (StatusCode, Vec<u8>) {
        let mut builder = Request::builder().method(method).uri(uri);
        if body.is_some() {
            builder = builder.header("content-type", "application/json");
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
        let bytes = response.into_body().collect().await.unwrap().to_bytes();
        (status, bytes.to_vec())
    }

    fn parse<T: DeserializeOwned>(bytes: &[u8]) -> T {
        serde_json::from_slice(bytes)
            .unwrap_or_else(|err| panic!("{err}: {}", String::from_utf8_lossy(bytes)))
    }

    fn leg_day() -> SessionBody {
        SessionBody::Strength {
            exercises: vec![
                Exercise {
                    name: "squat".into(),
                    sets: vec![
                        ExerciseSet::Reps {
                            reps: 5,
                            weight: 100.0,
                        };
                        3
                    ],
                },
                Exercise {
                    name: "plank".into(),
                    sets: vec![ExerciseSet::Hold { duration: 60 }],
                },
            ],
        }
    }

    fn thousands() -> SessionBody {
        SessionBody::Run {
            distance: 6_000,
            duration: 1_770,
            intervals: vec![Interval {
                repetitions: 6,
                distance: 1_000,
                duration: 220,
                recovery: 90,
            }],
        }
    }

    async fn save(app: &axum::Router, name: &str, body: SessionBody) -> Preset {
        let (status, bytes) = call(
            app,
            "POST",
            "/api/presets",
            Some(json!({ "name": name, "body": body })),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::CREATED,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        parse(&bytes)
    }

    async fn listed(app: &axum::Router, uri: &str) -> Vec<Preset> {
        let (status, bytes) = call(app, "GET", uri, None).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        parse(&bytes)
    }

    #[tokio::test]
    async fn creates_reads_changes_and_deletes_a_preset() {
        let app = app();
        let name = unique("Leg day");
        let created = save(&app, &format!("  {name} "), leg_day()).await;
        assert_eq!(created.name, name, "the name is trimmed");
        assert_eq!(created.body, leg_day());

        let (status, bytes) =
            call(&app, "GET", &format!("/api/presets/{}", created.id), None).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(parse::<Preset>(&bytes), created);

        let renamed = unique("Thousands");
        let (status, bytes) = call(
            &app,
            "PUT",
            &format!("/api/presets/{}", created.id),
            Some(json!({ "name": renamed, "body": thousands() })),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let changed: Preset = parse(&bytes);
        assert_eq!(changed.id, created.id);
        assert_eq!(changed.name, renamed);
        assert_eq!(changed.body, thousands());

        let (status, _) = call(
            &app,
            "DELETE",
            &format!("/api/presets/{}", created.id),
            None,
        )
        .await;
        assert_eq!(status, StatusCode::NO_CONTENT);
        let (status, _) = call(&app, "GET", &format!("/api/presets/{}", created.id), None).await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        let (status, _) = call(
            &app,
            "DELETE",
            &format!("/api/presets/{}", created.id),
            None,
        )
        .await;
        assert_eq!(status, StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn lists_by_sport_then_name_and_filters_by_sport() {
        let app = app();
        let tag = Uuid::new_v4().simple().to_string();
        let upper = save(&app, &format!("b upper {tag}"), leg_day()).await;
        let legs = save(&app, &format!("A legs {tag}"), leg_day()).await;
        let run = save(&app, &format!("z thousands {tag}"), thousands()).await;

        let ours = |presets: Vec<Preset>| -> Vec<Uuid> {
            presets
                .into_iter()
                .filter(|preset| preset.name.ends_with(&tag))
                .map(|preset| preset.id)
                .collect()
        };
        assert_eq!(
            ours(listed(&app, "/api/presets").await),
            vec![run.id, legs.id, upper.id]
        );
        assert_eq!(
            ours(listed(&app, "/api/presets?sport=strength").await),
            vec![legs.id, upper.id]
        );
        assert_eq!(
            ours(listed(&app, "/api/presets?sport=run").await),
            vec![run.id]
        );
        assert!(ours(listed(&app, "/api/presets?sport=ski").await).is_empty());

        for preset in [upper, legs, run] {
            call(&app, "DELETE", &format!("/api/presets/{}", preset.id), None).await;
        }
    }

    #[tokio::test]
    async fn a_name_is_taken_regardless_of_case() {
        let app = app();
        let name = unique("Leg day");
        let first = save(&app, &name, leg_day()).await;

        let (status, bytes) = call(
            &app,
            "POST",
            "/api/presets",
            Some(json!({ "name": name.to_uppercase(), "body": thousands() })),
        )
        .await;
        assert_eq!(status, StatusCode::CONFLICT);
        assert_eq!(
            parse::<String>(&bytes),
            "A preset with that name already exists"
        );

        let other = save(&app, &unique("Thousands"), thousands()).await;
        let (status, _) = call(
            &app,
            "PUT",
            &format!("/api/presets/{}", other.id),
            Some(json!({ "name": name, "body": thousands() })),
        )
        .await;
        assert_eq!(status, StatusCode::CONFLICT);

        // Keeping its own name, in another case, is not a clash.
        let (status, bytes) = call(
            &app,
            "PUT",
            &format!("/api/presets/{}", first.id),
            Some(json!({ "name": name.to_lowercase(), "body": leg_day() })),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );

        for preset in [first, other] {
            call(&app, "DELETE", &format!("/api/presets/{}", preset.id), None).await;
        }
    }

    #[tokio::test]
    async fn rejects_a_bad_name_or_body() {
        let app = app();
        let cases = [
            (json!({ "name": " ", "body": leg_day() }), "Name the preset"),
            (
                json!({ "name": unique("Steady"), "body": { "sport": "run", "distance": 0, "duration": 1800 } }),
                "A preset needs a distance and a time",
            ),
            (
                json!({ "name": unique("Empty"), "body": { "sport": "strength", "exercises": [] } }),
                "Name each exercise and give it a set",
            ),
            (
                json!({ "name": unique("Short"), "body": { "sport": "run", "distance": 1000, "duration": 220, "intervals": [{ "repetitions": 4, "distance": 1000, "duration": 220 }] } }),
                "Each interval needs repeats, and a distance or a time",
            ),
        ];
        for (input, message) in cases {
            let (status, bytes) = call(&app, "POST", "/api/presets", Some(input)).await;
            assert_eq!(status, StatusCode::BAD_REQUEST, "{message}");
            assert_eq!(parse::<String>(&bytes), message);
        }

        let (status, _) = call(
            &app,
            "PUT",
            &format!("/api/presets/{}", Uuid::new_v4()),
            Some(json!({ "name": unique("Missing"), "body": leg_day() })),
        )
        .await;
        assert_eq!(status, StatusCode::NOT_FOUND);
    }
}
