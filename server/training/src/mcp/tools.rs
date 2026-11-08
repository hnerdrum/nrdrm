//! The eight tools an agent calls on the training log.

use std::sync::Arc;

use chrono::{Datelike, Duration, NaiveDate};
use deadpool_diesel::postgres::Pool;
use rmcp::handler::server::router::tool::ToolRouter;
use rmcp::handler::server::wrapper::Parameters;
use rmcp::model::{ServerCapabilities, ServerConfig};
use rmcp::{tool, tool_handler, tool_router, Json, ServerHandler};
use schemars::JsonSchema;
use serde::Serialize;

use crate::clock::Clock;
use crate::database::session::{self, SessionStoreError};
use crate::domain::session::Sport;
use crate::domain::week::{week_totals, WeekTotals};

use super::convert::{apply_update, prepare_ride, prepare_run, prepare_ski, prepare_strength};
use super::input::{
    DeleteQuery, DistanceSession, LatestQuery, SportName, StrengthSession, UpdateQuery, WeekQuery,
};
use super::render::{render, RenderedSession};

#[derive(Clone)]
pub(crate) struct TrainingTools {
    db: Pool,
    clock: Arc<dyn Clock>,
    tool_router: ToolRouter<Self>,
}

impl TrainingTools {
    pub(crate) fn new(db: Pool, clock: Arc<dyn Clock>) -> Self {
        Self {
            db,
            clock,
            tool_router: Self::tool_router(),
        }
    }

    async fn saved(
        &self,
        prepared: Result<super::convert::PreparedSession, &'static str>,
    ) -> Result<Json<RenderedSession>, String> {
        let prepared = prepared.map_err(str::to_string)?;
        let session = session::create(&self.db, prepared.on_date, prepared.body)
            .await
            .map_err(explain)?;
        Ok(Json(render(&session)))
    }
}

#[tool_router(router = tool_router)]
impl TrainingTools {
    #[tool(
        description = "The Monday to Sunday week that contains a date, with each session and the week's figures. The date defaults to today in Europe/Oslo.",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            open_world_hint = false
        )
    )]
    async fn week(&self, Parameters(query): Parameters<WeekQuery>) -> Result<Json<Week>, String> {
        let on_date = query.on_date.unwrap_or_else(|| self.clock.today());
        let from = monday_of(on_date);
        let to = from + Duration::days(6);
        let stored = session::list(&self.db, from, to).await.map_err(explain)?;
        let domain_sessions: Vec<crate::domain::session::Session> = stored
            .iter()
            .map(|session| crate::domain::session::Session {
                on_date: session.on_date,
                body: session.body.clone(),
            })
            .collect();
        let totals = week_totals(&domain_sessions, from);
        let sessions: Vec<RenderedSession> = stored.iter().map(render).collect();
        let text = describe_week(from, to, &totals, &sessions);
        Ok(Json(Week {
            from,
            to,
            run_minutes: f64::from(totals.run_seconds) / 60.0,
            ride_minutes: f64::from(totals.ride_seconds) / 60.0,
            ski_kilometres: f64::from(totals.ski_metres) / 1000.0,
            ski_minutes: f64::from(totals.ski_seconds) / 60.0,
            strength_sessions: totals.strength_sessions,
            sessions,
            text,
        }))
    }

    #[tool(
        description = "The newest session of one sport on or before a date. The date defaults to today in Europe/Oslo.",
        annotations(
            read_only_hint = true,
            destructive_hint = false,
            open_world_hint = false
        )
    )]
    async fn latest_session(
        &self,
        Parameters(query): Parameters<LatestQuery>,
    ) -> Result<Json<Latest>, String> {
        let through = query.through.unwrap_or_else(|| self.clock.today());
        let sport = sport(query.sport);
        let stored = session::latest(&self.db, sport, through)
            .await
            .map_err(explain)?;
        let session = stored.as_ref().map(render);
        let text = match &session {
            Some(session) => session.text.clone(),
            None => format!("No {} on or before {through}.", sport.as_str()),
        };
        Ok(Json(Latest { session, text }))
    }

    #[tool(
        description = "Log a run. Distance is kilometres and time is minutes. With intervals, the repeats are the session.",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            open_world_hint = false
        )
    )]
    async fn log_run(
        &self,
        Parameters(input): Parameters<DistanceSession>,
    ) -> Result<Json<RenderedSession>, String> {
        self.saved(prepare_run(&input, self.clock.as_ref())).await
    }

    #[tool(
        description = "Log a ride. Distance is kilometres and time is minutes. With intervals, the repeats are the session.",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            open_world_hint = false
        )
    )]
    async fn log_ride(
        &self,
        Parameters(input): Parameters<DistanceSession>,
    ) -> Result<Json<RenderedSession>, String> {
        self.saved(prepare_ride(&input, self.clock.as_ref())).await
    }

    #[tool(
        description = "Log a ski. Distance is kilometres and time is minutes. With intervals, the repeats are the session.",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            open_world_hint = false
        )
    )]
    async fn log_ski(
        &self,
        Parameters(input): Parameters<DistanceSession>,
    ) -> Result<Json<RenderedSession>, String> {
        self.saved(prepare_ski(&input, self.clock.as_ref())).await
    }

    #[tool(
        description = "Log a strength session. A set is reps and an optional weight in kilograms, or a hold in seconds.",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            open_world_hint = false
        )
    )]
    async fn log_strength(
        &self,
        Parameters(input): Parameters<StrengthSession>,
    ) -> Result<Json<RenderedSession>, String> {
        self.saved(prepare_strength(&input, self.clock.as_ref()))
            .await
    }

    #[tool(
        description = "Change one session. A field that is omitted stays as it is, and the sport stays the same.",
        annotations(
            read_only_hint = false,
            destructive_hint = false,
            open_world_hint = false
        )
    )]
    async fn update_session(
        &self,
        Parameters(query): Parameters<UpdateQuery>,
    ) -> Result<Json<RenderedSession>, String> {
        let stored = session::find(&self.db, query.id).await.map_err(explain)?;
        let prepared =
            apply_update(stored.on_date, &stored.body, &query.change()).map_err(str::to_string)?;
        let saved = session::update(&self.db, query.id, prepared.on_date, prepared.body)
            .await
            .map_err(explain)?;
        Ok(Json(render(&saved)))
    }

    #[tool(
        description = "Delete one session.",
        annotations(
            read_only_hint = false,
            destructive_hint = true,
            open_world_hint = false
        )
    )]
    async fn delete_session(
        &self,
        Parameters(query): Parameters<DeleteQuery>,
    ) -> Result<Json<RenderedSession>, String> {
        let stored = session::find(&self.db, query.id).await.map_err(explain)?;
        session::delete(&self.db, query.id).await.map_err(explain)?;
        let mut rendered = render(&stored);
        rendered.text = format!("Deleted. {}", rendered.text);
        Ok(Json(rendered))
    }
}

#[tool_handler(router = self.tool_router)]
impl ServerHandler for TrainingTools {
    fn get_info(&self) -> ServerConfig {
        ServerConfig::new(ServerCapabilities::builder().enable_tools().build()).with_instructions(
            "The owner's training log. Distance is kilometres and time is minutes. A week runs Monday to Sunday, Europe/Oslo.",
        )
    }
}

#[derive(Debug, Serialize, JsonSchema)]
struct Week {
    from: NaiveDate,
    to: NaiveDate,
    sessions: Vec<RenderedSession>,
    run_minutes: f64,
    ride_minutes: f64,
    ski_kilometres: f64,
    ski_minutes: f64,
    strength_sessions: u32,
    text: String,
}

#[derive(Debug, Serialize, JsonSchema)]
struct Latest {
    session: Option<RenderedSession>,
    text: String,
}

fn sport(name: SportName) -> Sport {
    match name {
        SportName::Run => Sport::Run,
        SportName::Ride => Sport::Ride,
        SportName::Ski => Sport::Ski,
        SportName::Strength => Sport::Strength,
    }
}

fn explain(err: SessionStoreError) -> String {
    match err {
        SessionStoreError::NotFound => "Session not found".to_string(),
        SessionStoreError::Connection | SessionStoreError::Unknown => {
            "Couldn't reach the training log.".to_string()
        }
    }
}

fn monday_of(date: NaiveDate) -> NaiveDate {
    date - Duration::days(i64::from(date.weekday().num_days_from_monday()))
}

fn describe_week(
    monday: NaiveDate,
    sunday: NaiveDate,
    totals: &WeekTotals,
    sessions: &[RenderedSession],
) -> String {
    let mut text = format!(
        "Week of {monday} to {sunday}. Run {}. Ride {}. Ski {} km in {}. Strength {}.",
        minutes(totals.run_seconds),
        minutes(totals.ride_seconds),
        kilometres(totals.ski_metres),
        minutes(totals.ski_seconds),
        totals.strength_sessions,
    );
    if sessions.is_empty() {
        text.push_str(" Nothing logged this week.");
        return text;
    }
    for session in sessions {
        text.push(' ');
        text.push_str(&session.text);
    }
    text
}

fn minutes(seconds: u32) -> String {
    let whole = seconds / 60;
    let rest = seconds % 60;
    if rest == 0 {
        format!("{whole} min")
    } else {
        format!("{whole}:{rest:02}")
    }
}

fn kilometres(metres: u32) -> String {
    let whole = metres / 1000;
    let fraction = metres % 1000;
    if fraction == 0 {
        return whole.to_string();
    }
    format!("{whole}.{fraction:03}")
        .trim_end_matches('0')
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn date(year: i32, month: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(year, month, day).unwrap()
    }

    #[test]
    fn the_week_starts_on_monday() {
        let sunday = date(2026, 11, 8);
        let monday = date(2026, 11, 2);
        assert_eq!(monday_of(sunday), monday);
        assert_eq!(monday_of(monday), monday);
    }

    #[test]
    fn an_empty_week_names_the_week_and_the_zeros() {
        let text = describe_week(
            date(2026, 11, 2),
            date(2026, 11, 8),
            &WeekTotals::default(),
            &[],
        );
        assert_eq!(
            text,
            "Week of 2026-11-02 to 2026-11-08. Run 0 min. Ride 0 min. Ski 0 km in 0 min. Strength 0. Nothing logged this week."
        );
    }

    #[test]
    fn a_logged_week_keeps_the_zeros_and_the_session() {
        let session = RenderedSession {
            id: Uuid::nil(),
            on_date: date(2026, 11, 8),
            sport: "run".to_string(),
            kilometres: Some(10.0),
            minutes: Some(57.0),
            pace: Some("5:42 /km".to_string()),
            speed_kmh: None,
            intervals: Vec::new(),
            exercises: Vec::new(),
            source: None,
            text: "Run on 2026-11-08, 10 km in 57 min, 5:42 /km.".to_string(),
        };
        let text = describe_week(
            date(2026, 11, 2),
            date(2026, 11, 8),
            &WeekTotals {
                run_seconds: 3_420,
                ..WeekTotals::default()
            },
            &[session],
        );
        assert_eq!(
            text,
            "Week of 2026-11-02 to 2026-11-08. Run 57 min. Ride 0 min. Ski 0 km in 0 min. Strength 0. Run on 2026-11-08, 10 km in 57 min, 5:42 /km."
        );
    }
}
