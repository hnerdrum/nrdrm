use axum::extract::State;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{Json, Router};
use chrono::{Duration, NaiveDate};
use serde::Serialize;
use tracing::error;

use super::main::AppState;
use crate::activities::ActivityClientError;
use crate::database::session::{self, Session, SessionStoreError};
use crate::domain::import::import_activities;

const SYNC_LOOKBACK_DAYS: i64 = 29;

pub fn routes() -> Router<AppState> {
    Router::new().route("/api/sync", axum::routing::post(sync))
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct SyncResponse {
    pub(crate) sessions: Vec<Session>,
    pub(crate) skipped: Vec<String>,
}

#[derive(Debug)]
pub(crate) enum SyncError {
    Unavailable,
    Failed,
}

impl std::fmt::Display for SyncError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::Unavailable => "Garmin didn't respond",
            Self::Failed => "sync failed",
        })
    }
}

impl From<SessionStoreError> for SyncError {
    fn from(_: SessionStoreError) -> Self {
        Self::Failed
    }
}

impl IntoResponse for SyncError {
    fn into_response(self) -> axum::response::Response {
        let (status, message) = match self {
            Self::Unavailable => (StatusCode::BAD_GATEWAY, "Garmin didn't respond."),
            Self::Failed => (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error"),
        };
        (status, Json(message)).into_response()
    }
}

fn sync_window(today: NaiveDate) -> (NaiveDate, NaiveDate) {
    (today - Duration::days(SYNC_LOOKBACK_DAYS), today)
}

pub(crate) async fn run_sync(state: &AppState) -> Result<SyncResponse, SyncError> {
    let today = state.clock.today();
    let (from, to) = sync_window(today);
    let summaries =
        state
            .activities
            .summaries(from, to)
            .await
            .map_err(|err: ActivityClientError| {
                error!("activity sync failed: {err}");
                SyncError::Unavailable
            })?;
    let stored = session::stored_sources(&state.db).await?;
    let plan = import_activities(&summaries, today, &stored);
    let sessions = session::insert_imported(&state.db, plan.sessions).await?;
    Ok(SyncResponse {
        sessions,
        skipped: plan.skipped,
    })
}

async fn sync(State(state): State<AppState>) -> Result<Json<SyncResponse>, SyncError> {
    run_sync(&state).await.map(Json)
}

#[cfg(test)]
mod tests {
    use std::sync::{Arc, Mutex};

    use async_trait::async_trait;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use chrono::{NaiveDate, NaiveDateTime};
    use http_body_util::BodyExt;
    use serde::Deserialize;
    use tower::ServiceExt;

    use crate::activities::{ActivityClient, ActivityClientError};
    use crate::clock::FixedClock;
    use crate::database::session::{self, Session};
    use crate::domain::import::{ActivityKind, ActivitySummary, PlannedSession};
    use crate::domain::session::SessionBody;
    use crate::domain::source::{ActivityProvider, ActivitySource};
    use crate::router::main::{init_router, test_state, AppState};

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct SyncBody {
        sessions: Vec<Session>,
        skipped: Vec<String>,
    }

    struct Fixture {
        summaries: Vec<ActivitySummary>,
        requested: Arc<Mutex<Option<(NaiveDate, NaiveDate)>>>,
    }

    #[async_trait]
    impl ActivityClient for Fixture {
        async fn summaries(
            &self,
            from: NaiveDate,
            to: NaiveDate,
        ) -> Result<Vec<ActivitySummary>, ActivityClientError> {
            *self.requested.lock().expect("range lock") = Some((from, to));
            Ok(self.summaries.clone())
        }
    }

    struct Unavailable;

    #[async_trait]
    impl ActivityClient for Unavailable {
        async fn summaries(
            &self,
            _from: NaiveDate,
            _to: NaiveDate,
        ) -> Result<Vec<ActivitySummary>, ActivityClientError> {
            Err(ActivityClientError)
        }
    }

    fn today() -> NaiveDate {
        NaiveDate::from_ymd_opt(2400, 8, 16).unwrap()
    }

    fn at(day: u32, hour: u32) -> NaiveDateTime {
        NaiveDate::from_ymd_opt(2400, 8, day)
            .unwrap()
            .and_hms_opt(hour, 0, 0)
            .unwrap()
    }

    fn source(activity_id: &str) -> ActivitySource {
        ActivitySource {
            provider: ActivityProvider::Garmin,
            activity_id: activity_id.to_string(),
        }
    }

    fn activity(
        activity_id: &str,
        name: &str,
        start: NaiveDateTime,
        kind: ActivityKind,
        distance: Option<f64>,
        duration: Option<f64>,
    ) -> ActivitySummary {
        ActivitySummary {
            source: source(activity_id),
            name: name.to_string(),
            local_start: start,
            distance_metres: distance,
            duration_seconds: duration,
            kind,
        }
    }

    fn fixture_summaries() -> Vec<ActivitySummary> {
        vec![
            activity(
                "run-2400",
                "Morning run",
                at(14, 7),
                ActivityKind::Run,
                Some(5_000.4),
                Some(1_500.6),
            ),
            activity(
                "run-2400",
                "Morning run",
                at(14, 7),
                ActivityKind::Run,
                Some(9_999.0),
                Some(9_999.0),
            ),
            activity(
                "strength-2400",
                "Strength",
                at(14, 18),
                ActivityKind::Other,
                None,
                Some(2_400.0),
            ),
            activity(
                "ski-2400",
                "Nordmarka",
                at(15, 10),
                ActivityKind::Ski,
                Some(12_000.0),
                Some(3_600.0),
            ),
            activity(
                "future-2400",
                "Tomorrow",
                at(17, 8),
                ActivityKind::Run,
                Some(5_000.0),
                Some(1_500.0),
            ),
        ]
    }

    fn app(activities: Arc<dyn ActivityClient>) -> (axum::Router, AppState) {
        let base = test_state();
        let state = AppState {
            db: base.db,
            config: base.config,
            activities,
            clock: Arc::new(FixedClock(today())),
        };
        (init_router(state.clone()), state)
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

    fn parse<T: serde::de::DeserializeOwned>(bytes: &[u8]) -> T {
        serde_json::from_slice(bytes)
            .unwrap_or_else(|err| panic!("{err}: {}", String::from_utf8_lossy(bytes)))
    }

    async fn forget(state: &AppState, from: NaiveDate, to: NaiveDate) {
        use crate::database::schema::{
            training_session as session, training_session_source as session_source,
        };
        use diesel::prelude::*;
        state
            .db
            .get()
            .await
            .expect("database connection")
            .interact(move |conn| {
                let ids: Vec<uuid::Uuid> = session::table
                    .filter(session::on_date.ge(from))
                    .filter(session::on_date.le(to))
                    .select(session::id)
                    .load(conn)?;
                diesel::delete(
                    session_source::table.filter(session_source::session_id.eq_any(&ids)),
                )
                .execute(conn)?;
                diesel::delete(session::table.filter(session::id.eq_any(&ids))).execute(conn)
            })
            .await
            .expect("session delete")
            .expect("session delete");
    }

    #[tokio::test]
    async fn sync_imports_a_run_and_a_ski_and_names_the_rest() {
        let requested = Arc::new(Mutex::new(None));
        let (app, state) = app(Arc::new(Fixture {
            summaries: fixture_summaries(),
            requested: Arc::clone(&requested),
        }));
        let from = NaiveDate::from_ymd_opt(2400, 8, 1).unwrap();
        let to = NaiveDate::from_ymd_opt(2400, 8, 31).unwrap();
        forget(&state, from, to).await;

        let (status, bytes) = call(&app, "POST", "/api/sync", None).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let body: SyncBody = parse(&bytes);
        assert_eq!(body.skipped, vec!["Strength".to_string()]);
        assert_eq!(body.sessions.len(), 2);
        assert_eq!(
            body.sessions[0].on_date,
            NaiveDate::from_ymd_opt(2400, 8, 14).unwrap()
        );
        assert_eq!(
            body.sessions[0].body,
            SessionBody::Run {
                distance: 5_000,
                duration: 1_501,
                intervals: vec![],
            }
        );
        assert_eq!(body.sessions[0].source, Some(source("run-2400")));
        assert_eq!(
            body.sessions[1].body,
            SessionBody::Ski {
                distance: 12_000,
                duration: 3_600,
                intervals: vec![],
            }
        );
        assert_eq!(body.sessions[1].source, Some(source("ski-2400")));
        assert!(serde_json::to_value(&body.sessions[1].body)
            .unwrap()
            .get("withPack")
            .is_none());
        assert_eq!(
            *requested.lock().unwrap(),
            Some(super::sync_window(today()))
        );

        let (status, bytes) = call(&app, "POST", "/api/sync", None).await;
        assert_eq!(status, StatusCode::OK);
        let again: SyncBody = parse(&bytes);
        assert!(again.sessions.is_empty());
        assert_eq!(again.skipped, vec!["Strength".to_string()]);

        let ski_id = body.sessions[1].id;
        let (status, bytes) = call(
            &app,
            "PUT",
            &format!("/api/sessions/{ski_id}"),
            Some(r#"{"onDate":"2400-08-15","body":{"sport":"ski","distance":15000,"duration":4000}}"#),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&bytes)
        );
        let updated: Session = parse(&bytes);
        assert_eq!(updated.source, Some(source("ski-2400")));
        assert_eq!(
            updated.body,
            SessionBody::Ski {
                distance: 15_000,
                duration: 4_000,
                intervals: vec![],
            }
        );

        let (status, bytes) = call(
            &app,
            "GET",
            "/api/sessions?from=2400-08-01&to=2400-08-31",
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let listed: Vec<Session> = parse(&bytes);
        assert_eq!(listed.len(), 2);

        for session in &body.sessions {
            let (status, _) = call(
                &app,
                "DELETE",
                &format!("/api/sessions/{}", session.id),
                None,
            )
            .await;
            assert_eq!(status, StatusCode::NO_CONTENT);
        }

        let (status, bytes) = call(&app, "POST", "/api/sync", None).await;
        assert_eq!(status, StatusCode::OK);
        let after_delete: SyncBody = parse(&bytes);
        assert!(after_delete.sessions.is_empty());

        let (status, bytes) = call(
            &app,
            "GET",
            "/api/sessions?from=2400-08-01&to=2400-08-31",
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let listed: Vec<Session> = parse(&bytes);
        assert!(listed.is_empty());

        forget(&state, from, to).await;
    }

    #[tokio::test]
    async fn sync_says_when_garmin_does_not_respond() {
        let (app, _) = app(Arc::new(Unavailable));
        let (status, bytes) = call(&app, "POST", "/api/sync", None).await;
        assert_eq!(status, StatusCode::BAD_GATEWAY);
        let message: String = parse(&bytes);
        assert_eq!(message, "Garmin didn't respond.");
    }

    #[tokio::test]
    async fn a_repeated_garmin_activity_is_stored_once() {
        let state = test_state();
        let on_date = NaiveDate::from_ymd_opt(2400, 9, 1).unwrap();
        forget(&state, on_date, on_date).await;

        let planned = vec![PlannedSession {
            on_date,
            body: SessionBody::Run {
                distance: 1_000,
                duration: 300,
                intervals: vec![],
            },
            source: source("shared-2400"),
        }];
        let saved = session::insert_imported(&state.db, planned.clone())
            .await
            .expect("insert");
        assert_eq!(saved.len(), 1);
        assert_eq!(
            saved[0].source.as_ref().map(|source| source.provider),
            Some(ActivityProvider::Garmin)
        );

        let again = session::insert_imported(&state.db, planned)
            .await
            .expect("insert");
        assert!(again.is_empty());

        forget(&state, on_date, on_date).await;
    }

    struct ManualClock(std::sync::Mutex<chrono::DateTime<chrono_tz::Tz>>);

    impl ManualClock {
        fn new(now: chrono::DateTime<chrono_tz::Tz>) -> Self {
            Self(std::sync::Mutex::new(now))
        }

        fn set(&self, now: chrono::DateTime<chrono_tz::Tz>) {
            *self.0.lock().expect("clock") = now;
        }
    }

    impl crate::clock::Clock for ManualClock {
        fn now(&self) -> chrono::DateTime<chrono_tz::Tz> {
            *self.0.lock().expect("clock")
        }
    }

    fn oslo(
        year: i32,
        month: u32,
        day: u32,
        hour: u32,
        minute: u32,
    ) -> chrono::DateTime<chrono_tz::Tz> {
        use chrono::TimeZone;
        chrono_tz::Europe::Oslo
            .with_ymd_and_hms(year, month, day, hour, minute, 0)
            .single()
            .unwrap_or_else(|| panic!("{year}-{month:02}-{day:02} {hour:02}:{minute:02}"))
    }

    #[tokio::test]
    async fn the_night_path_calls_import_at_two() {
        let from = NaiveDate::from_ymd_opt(2099, 6, 1).unwrap();
        let morning = NaiveDate::from_ymd_opt(2099, 6, 15).unwrap();
        let to = NaiveDate::from_ymd_opt(2099, 6, 30).unwrap();
        let clock = Arc::new(ManualClock::new(oslo(2099, 6, 14, 22, 0)));
        let requested = Arc::new(Mutex::new(None));
        let summaries = vec![
            activity(
                "night-2099",
                "Night run",
                morning.and_hms_opt(1, 0, 0).unwrap(),
                ActivityKind::Run,
                Some(8_000.0),
                Some(2_400.0),
            ),
            activity(
                "night-2099-strength",
                "Strength",
                morning.and_hms_opt(1, 30, 0).unwrap(),
                ActivityKind::Other,
                None,
                Some(2_400.0),
            ),
        ];
        let base = test_state();
        let state = AppState {
            db: base.db,
            config: base.config,
            activities: Arc::new(Fixture {
                summaries,
                requested: Arc::clone(&requested),
            }),
            clock: Arc::clone(&clock) as Arc<dyn crate::clock::Clock>,
        };
        forget(&state, from, to).await;

        let clock_for_sleep = Arc::clone(&clock);
        let result = crate::schedule::wait_and_sync(&state, move |deadline| {
            let clock = Arc::clone(&clock_for_sleep);
            async move {
                assert_eq!(deadline, oslo(2099, 6, 15, 2, 0));
                clock.set(deadline);
            }
        })
        .await
        .expect("night sync");

        assert_eq!(
            *requested.lock().unwrap(),
            Some(super::sync_window(morning))
        );
        assert_eq!(result.skipped, vec!["Strength".to_string()]);
        assert_eq!(result.sessions.len(), 1);
        assert_eq!(result.sessions[0].on_date, morning);
        assert_eq!(
            result.sessions[0].body,
            SessionBody::Run {
                distance: 8_000,
                duration: 2_400,
                intervals: vec![],
            }
        );

        forget(&state, from, to).await;
    }

    #[tokio::test]
    async fn the_night_path_leaves_rows_when_garmin_does_not_respond() {
        let from = NaiveDate::from_ymd_opt(2099, 7, 1).unwrap();
        let to = NaiveDate::from_ymd_opt(2099, 7, 31).unwrap();
        let clock = Arc::new(ManualClock::new(oslo(2099, 7, 14, 22, 0)));
        let base = test_state();
        let state = AppState {
            db: base.db,
            config: base.config,
            activities: Arc::new(Unavailable),
            clock: Arc::clone(&clock) as Arc<dyn crate::clock::Clock>,
        };
        forget(&state, from, to).await;
        let before = session::list(&state.db, from, to).await.expect("list");

        let clock_for_sleep = Arc::clone(&clock);
        let result = crate::schedule::wait_and_sync(&state, move |deadline| {
            let clock = Arc::clone(&clock_for_sleep);
            async move {
                clock.set(deadline);
            }
        })
        .await;

        assert!(matches!(result, Err(super::SyncError::Unavailable)));
        let after = session::list(&state.db, from, to).await.expect("list");
        assert_eq!(after, before);
    }
}
