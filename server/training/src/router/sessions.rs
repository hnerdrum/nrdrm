use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Json, Router};
use chrono::NaiveDate;
use serde::Deserialize;
use uuid::Uuid;

use super::main::AppState;
use crate::database::session::{self, Session, SessionStoreError};
use crate::domain::session::{SessionBody, Sport};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/sessions", axum::routing::get(list).post(create))
        .route("/api/sessions/latest", axum::routing::get(latest))
        .route(
            "/api/sessions/:id",
            axum::routing::get(read).put(update).delete(remove),
        )
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SessionInput {
    on_date: NaiveDate,
    body: SessionBody,
}

#[derive(Debug, Deserialize)]
struct DateRange {
    #[serde(rename = "from")]
    start: NaiveDate,
    #[serde(rename = "to")]
    end: NaiveDate,
}

enum ApiError {
    NotFound,
    BadRequest(&'static str),
    Unavailable,
}

impl From<SessionStoreError> for ApiError {
    fn from(err: SessionStoreError) -> Self {
        match err {
            SessionStoreError::NotFound => Self::NotFound,
            SessionStoreError::Connection | SessionStoreError::Unknown => Self::Unavailable,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        let (status, message) = match self {
            Self::NotFound => (StatusCode::NOT_FOUND, "Session not found"),
            Self::BadRequest(message) => (StatusCode::BAD_REQUEST, message),
            Self::Unavailable => (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error"),
        };
        (status, Json(message)).into_response()
    }
}

async fn create(
    State(state): State<AppState>,
    Json(input): Json<SessionInput>,
) -> Result<(StatusCode, Json<Session>), ApiError> {
    let saved = session::create(&state.db, input.on_date, input.body).await?;
    Ok((StatusCode::CREATED, Json(saved)))
}

async fn list(
    State(state): State<AppState>,
    Query(range): Query<DateRange>,
) -> Result<Json<Vec<Session>>, ApiError> {
    if range.start > range.end {
        return Err(ApiError::BadRequest("From is after to"));
    }
    let sessions = session::list(&state.db, range.start, range.end).await?;
    Ok(Json(sessions))
}

#[derive(Debug, Deserialize)]
struct Latest {
    sport: Sport,
    through: NaiveDate,
}

async fn latest(
    State(state): State<AppState>,
    Query(query): Query<Latest>,
) -> Result<Json<Option<Session>>, ApiError> {
    let saved = session::latest(&state.db, query.sport, query.through).await?;
    Ok(Json(saved))
}

async fn read(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Session>, ApiError> {
    let saved = session::find(&state.db, id).await?;
    Ok(Json(saved))
}

async fn update(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(input): Json<SessionInput>,
) -> Result<Json<Session>, ApiError> {
    let saved = session::update(&state.db, id, input.on_date, input.body).await?;
    Ok(Json(saved))
}

async fn remove(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<StatusCode, ApiError> {
    session::delete(&state.db, id).await?;
    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session::{Exercise, ExerciseSet, SessionBody};
    use crate::router::main::{init_router, test_state};
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use chrono::{Datelike, Duration, NaiveDate, Weekday};
    use http_body_util::BodyExt;
    use serde::de::DeserializeOwned;
    use tower::ServiceExt;
    use uuid::Uuid;

    fn week_containing(year: i32, month: u32, day: u32) -> (NaiveDate, NaiveDate) {
        let date = NaiveDate::from_ymd_opt(year, month, day).unwrap();
        let monday = date - Duration::days(i64::from(date.weekday().num_days_from_monday()));
        let sunday = monday + Duration::days(6);
        assert_eq!(monday.weekday(), Weekday::Mon);
        assert_eq!(sunday.weekday(), Weekday::Sun);
        (monday, sunday)
    }

    fn app() -> axum::Router {
        init_router(test_state())
    }

    async fn call(
        app: &axum::Router,
        method: &str,
        uri: &str,
        body: Option<&str>,
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

    async fn clear(app: &axum::Router, from: NaiveDate, to: NaiveDate) {
        let (status, bytes) = call(
            app,
            "GET",
            &format!("/api/sessions?from={from}&to={to}"),
            None,
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let sessions: Vec<Session> = parse(&bytes);
        for session in sessions {
            let (status, _) = call(
                app,
                "DELETE",
                &format!("/api/sessions/{}", session.id),
                None,
            )
            .await;
            assert_eq!(status, StatusCode::NO_CONTENT);
        }
    }

    async fn save(app: &axum::Router, on_date: NaiveDate, body: SessionBody) -> Session {
        let (status, bytes) = call(app, "POST", "/api/sessions", Some(&input(on_date, body))).await;
        assert_eq!(
            status,
            StatusCode::CREATED,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        parse(&bytes)
    }

    fn strength(name: &str) -> SessionBody {
        SessionBody::Strength {
            exercises: vec![Exercise {
                name: name.into(),
                sets: vec![ExerciseSet {
                    reps: 5,
                    weight: 100.0,
                }],
            }],
        }
    }

    fn input(on_date: NaiveDate, body: SessionBody) -> String {
        serde_json::to_string(&serde_json::json!({
            "onDate": on_date,
            "body": body,
        }))
        .unwrap()
    }

    #[tokio::test]
    async fn saves_each_sport_and_lists_the_week() {
        let app = app();
        let (monday, sunday) = week_containing(2400, 1, 15);
        let before = monday - Duration::days(1);
        let after = sunday + Duration::days(1);
        clear(&app, before, after).await;

        let created = vec![
            (
                sunday,
                SessionBody::Strength {
                    exercises: vec![Exercise {
                        name: "squat".into(),
                        sets: vec![ExerciseSet {
                            reps: 5,
                            weight: 0.0,
                        }],
                    }],
                },
            ),
            (
                monday,
                SessionBody::Run {
                    distance: 5_000,
                    duration: 1_500,
                },
            ),
            (
                monday + Duration::days(1),
                SessionBody::Ride {
                    distance: 40_000,
                    duration: 3_600,
                },
            ),
            (
                monday + Duration::days(2),
                SessionBody::Ski {
                    distance: 12_000,
                    duration: 3_600,
                },
            ),
            (
                before,
                SessionBody::Run {
                    distance: 1_000,
                    duration: 300,
                },
            ),
            (
                after,
                SessionBody::Ride {
                    distance: 2_000,
                    duration: 400,
                },
            ),
        ];

        for (on_date, body) in &created {
            let (status, bytes) = call(
                &app,
                "POST",
                "/api/sessions",
                Some(&input(*on_date, body.clone())),
            )
            .await;
            assert_eq!(
                status,
                StatusCode::CREATED,
                "{}",
                String::from_utf8_lossy(&bytes)
            );
            let saved: Session = parse(&bytes);
            assert_eq!(saved.on_date, *on_date);
            assert_eq!(saved.body, *body);
        }

        let (status, bytes) = call(
            &app,
            "GET",
            &format!("/api/sessions?from={monday}&to={sunday}"),
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let listed: Vec<Session> = parse(&bytes);
        let listed: Vec<_> = listed
            .into_iter()
            .map(|session| (session.on_date, session.body))
            .collect();
        assert_eq!(
            listed,
            vec![
                (
                    monday,
                    SessionBody::Run {
                        distance: 5_000,
                        duration: 1_500,
                    },
                ),
                (
                    monday + Duration::days(1),
                    SessionBody::Ride {
                        distance: 40_000,
                        duration: 3_600,
                    },
                ),
                (
                    monday + Duration::days(2),
                    SessionBody::Ski {
                        distance: 12_000,
                        duration: 3_600,
                    },
                ),
                (
                    sunday,
                    SessionBody::Strength {
                        exercises: vec![Exercise {
                            name: "squat".into(),
                            sets: vec![ExerciseSet {
                                reps: 5,
                                weight: 0.0,
                            }],
                        }],
                    },
                ),
            ]
        );

        clear(&app, before, after).await;
    }

    #[tokio::test]
    async fn updates_a_ski() {
        let app = app();
        let (monday, sunday) = week_containing(2400, 2, 15);
        clear(&app, monday, sunday).await;

        let ski = SessionBody::Ski {
            distance: 8_000,
            duration: 2_400,
        };
        let (status, bytes) = call(&app, "POST", "/api/sessions", Some(&input(monday, ski))).await;
        assert_eq!(
            status,
            StatusCode::CREATED,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let saved: Session = parse(&bytes);

        let longer = SessionBody::Ski {
            distance: 12_000,
            duration: 3_600,
        };
        let (status, bytes) = call(
            &app,
            "PUT",
            &format!("/api/sessions/{}", saved.id),
            Some(&input(monday, longer.clone())),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let updated: Session = parse(&bytes);
        assert_eq!(updated.id, saved.id);
        assert_eq!(updated.on_date, monday);
        assert_eq!(updated.body, longer);

        let (status, bytes) = call(&app, "GET", &format!("/api/sessions/{}", saved.id), None).await;
        assert_eq!(status, StatusCode::OK);
        let read: Session = parse(&bytes);
        assert_eq!(read.body, longer);

        clear(&app, monday, sunday).await;
    }

    #[tokio::test]
    async fn deletes_a_session() {
        let app = app();
        let (monday, sunday) = week_containing(2400, 3, 15);
        clear(&app, monday, sunday).await;

        let (status, bytes) = call(
            &app,
            "POST",
            "/api/sessions",
            Some(&input(
                monday,
                SessionBody::Run {
                    distance: 3_000,
                    duration: 900,
                },
            )),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::CREATED,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let saved: Session = parse(&bytes);

        let (status, bytes) =
            call(&app, "DELETE", &format!("/api/sessions/{}", saved.id), None).await;
        assert_eq!(
            status,
            StatusCode::NO_CONTENT,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        assert!(bytes.is_empty());

        let (status, _) = call(&app, "GET", &format!("/api/sessions/{}", saved.id), None).await;
        assert_eq!(status, StatusCode::NOT_FOUND);

        let (status, bytes) = call(
            &app,
            "GET",
            &format!("/api/sessions?from={monday}&to={sunday}"),
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let listed: Vec<Session> = parse(&bytes);
        assert!(listed.is_empty());
    }

    #[tokio::test]
    async fn an_empty_range_lists_nothing() {
        let app = app();
        let (monday, sunday) = week_containing(2400, 4, 15);
        clear(&app, monday, sunday).await;

        let (status, bytes) = call(
            &app,
            "GET",
            &format!("/api/sessions?from={monday}&to={sunday}"),
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let listed: Vec<Session> = parse(&bytes);
        assert!(listed.is_empty());
    }

    #[tokio::test]
    async fn rejects_a_strength_body_that_includes_distance() {
        let app = app();
        let (status, _) = call(
            &app,
            "POST",
            "/api/sessions",
            Some(
                r#"{"onDate":"2400-05-02","body":{"sport":"strength","exercises":[],"distance":1000}}"#,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    }

    #[tokio::test]
    async fn missing_session_is_not_found() {
        let app = app();
        let id = Uuid::nil();
        let uri = format!("/api/sessions/{id}");
        let (status, _) = call(&app, "GET", &uri, None).await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        let (status, _) = call(
            &app,
            "PUT",
            &uri,
            Some(
                r#"{"onDate":"2400-06-01","body":{"sport":"run","distance":1000,"duration":300}}"#,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        let (status, _) = call(&app, "DELETE", &uri, None).await;
        assert_eq!(status, StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn rejects_a_reversed_date_range() {
        let app = app();
        let (status, bytes) = call(
            &app,
            "GET",
            "/api/sessions?from=2400-07-08&to=2400-07-02",
            None,
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        let message: String = parse(&bytes);
        assert_eq!(message, "From is after to");
    }

    #[tokio::test]
    async fn latest_is_the_newest_of_that_sport_on_or_before_the_date() {
        let app = app();
        let (status, bytes) = call(
            &app,
            "GET",
            "/api/sessions/latest?sport=strength&through=1970-01-01",
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let none: Option<Session> = parse(&bytes);
        assert!(none.is_none());

        let through = NaiveDate::from_ymd_opt(2400, 12, 15).unwrap();
        let earlier = through - Duration::days(10);
        let after = through + Duration::days(1);
        clear(&app, earlier, after).await;

        save(&app, earlier, strength("old")).await;
        let run = save(
            &app,
            through,
            SessionBody::Run {
                distance: 5_000,
                duration: 1_500,
            },
        )
        .await;
        let first = save(&app, through, strength("squat")).await;
        let second = save(&app, through, strength("bench")).await;
        save(&app, after, strength("future")).await;

        let (status, bytes) = call(
            &app,
            "GET",
            &format!("/api/sessions/latest?sport=run&through={through}"),
            None,
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let found: Option<Session> = parse(&bytes);
        let found = found.expect("a run on or before the date");
        assert_eq!(found.id, run.id);

        let (status, bytes) = call(
            &app,
            "GET",
            &format!("/api/sessions/latest?sport=strength&through={through}"),
            None,
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let found: Option<Session> = parse(&bytes);
        let found = found.expect("a strength session on or before the date");
        let expected = if first.id > second.id { first } else { second };
        assert_eq!(found.id, expected.id);
        assert_eq!(found.on_date, through);
        assert_eq!(found.body, expected.body);

        clear(&app, earlier, after).await;
    }
}
