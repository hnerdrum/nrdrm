use std::collections::HashSet;

use chrono::{NaiveDate, NaiveDateTime};

use super::session::SessionBody;
use super::source::ActivitySource;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ActivityKind {
    Run,
    Ride,
    Ski,
    Other,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ActivitySummary {
    pub source: ActivitySource,
    pub name: String,
    pub local_start: NaiveDateTime,
    pub distance_metres: Option<f64>,
    pub duration_seconds: Option<f64>,
    pub kind: ActivityKind,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlannedSession {
    pub on_date: NaiveDate,
    pub body: SessionBody,
    pub source: ActivitySource,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ImportPlan {
    pub sessions: Vec<PlannedSession>,
    pub skipped: Vec<String>,
}

pub fn import_activities(
    summaries: &[ActivitySummary],
    today: NaiveDate,
    stored: &HashSet<ActivitySource>,
) -> ImportPlan {
    let mut seen = stored.clone();
    let mut sessions = Vec::new();
    let mut skipped = Vec::new();

    for summary in summaries {
        if summary.local_start.date() > today {
            continue;
        }
        let Some(source) = canonical_source(&summary.source) else {
            skipped.push(summary_name(summary));
            continue;
        };
        if !seen.insert(source.clone()) {
            continue;
        }
        match planned(summary, source) {
            Some(session) => sessions.push(session),
            None => skipped.push(summary_name(summary)),
        }
    }

    ImportPlan { sessions, skipped }
}

fn canonical_source(source: &ActivitySource) -> Option<ActivitySource> {
    let activity_id = source.activity_id.trim();
    if activity_id.is_empty() {
        return None;
    }
    Some(ActivitySource {
        provider: source.provider,
        activity_id: activity_id.to_string(),
    })
}

fn planned(summary: &ActivitySummary, source: ActivitySource) -> Option<PlannedSession> {
    let body = match summary.kind {
        ActivityKind::Run => SessionBody::Run {
            distance: whole_units(summary.distance_metres?)?,
            duration: whole_units(summary.duration_seconds?)?,
            intervals: vec![],
        },
        ActivityKind::Ride => SessionBody::Ride {
            distance: whole_units(summary.distance_metres?)?,
            duration: whole_units(summary.duration_seconds?)?,
            intervals: vec![],
        },
        ActivityKind::Ski => SessionBody::Ski {
            distance: whole_units(summary.distance_metres?)?,
            duration: whole_units(summary.duration_seconds?)?,
            intervals: vec![],
        },
        ActivityKind::Other => return None,
    };
    Some(PlannedSession {
        on_date: summary.local_start.date(),
        body,
        source,
    })
}

fn summary_name(summary: &ActivitySummary) -> String {
    let name = summary.name.trim();
    if !name.is_empty() {
        return name.to_string();
    }
    "Untitled activity".to_string()
}

fn whole_units(value: f64) -> Option<u32> {
    if !value.is_finite() || value < 0.0 {
        return None;
    }
    let rounded = value.round();
    if rounded > f64::from(u32::MAX) {
        return None;
    }
    Some(rounded as u32)
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use chrono::{NaiveDate, NaiveDateTime};

    use super::*;
    use crate::domain::source::{ActivityProvider, ActivitySource};

    fn today() -> NaiveDate {
        NaiveDate::from_ymd_opt(2026, 11, 8).unwrap()
    }

    fn at(day: u32, hour: u32) -> NaiveDateTime {
        NaiveDate::from_ymd_opt(2026, 11, day)
            .unwrap()
            .and_hms_opt(hour, 30, 0)
            .unwrap()
    }

    fn source(activity_id: &str) -> ActivitySource {
        ActivitySource {
            provider: ActivityProvider::Garmin,
            activity_id: activity_id.to_string(),
        }
    }

    fn summary(
        source: ActivitySource,
        name: &str,
        start: NaiveDateTime,
        kind: ActivityKind,
        distance: Option<f64>,
        duration: Option<f64>,
    ) -> ActivitySummary {
        ActivitySummary {
            source,
            name: name.to_string(),
            local_start: start,
            distance_metres: distance,
            duration_seconds: duration,
            kind,
        }
    }

    #[test]
    fn a_run_uses_the_local_date_and_rounds_to_metres_and_seconds() {
        let run = summary(
            source("100"),
            "Morning run",
            at(6, 23),
            ActivityKind::Run,
            Some(10_234.6),
            Some(3_120.4),
        );

        let plan = import_activities(&[run], today(), &HashSet::new());

        assert!(plan.skipped.is_empty());
        assert_eq!(
            plan.sessions,
            vec![PlannedSession {
                on_date: NaiveDate::from_ymd_opt(2026, 11, 6).unwrap(),
                body: SessionBody::Run {
                    distance: 10_235,
                    duration: 3_120,
                    intervals: vec![],
                },
                source: source("100"),
            }]
        );
    }

    #[test]
    fn a_stored_activity_is_not_imported_again() {
        let run = summary(
            source("100"),
            "Morning run",
            at(6, 7),
            ActivityKind::Run,
            Some(5_000.0),
            Some(1_500.0),
        );
        let stored = HashSet::from([source("100")]);

        let plan = import_activities(&[run], today(), &stored);

        assert!(plan.sessions.is_empty());
        assert!(plan.skipped.is_empty());
    }

    #[test]
    fn a_duplicate_in_the_same_import_is_kept_once() {
        let first = summary(
            source("100"),
            "Morning run",
            at(6, 7),
            ActivityKind::Run,
            Some(5_000.0),
            Some(1_500.0),
        );
        let second = summary(
            source("100"),
            "Morning run",
            at(6, 7),
            ActivityKind::Run,
            Some(9_999.0),
            Some(9_999.0),
        );

        let plan = import_activities(&[first, second], today(), &HashSet::new());

        assert_eq!(plan.sessions.len(), 1);
        assert_eq!(
            plan.sessions[0].body,
            SessionBody::Run {
                distance: 5_000,
                duration: 1_500,
                intervals: vec![],
            }
        );
        assert!(plan.skipped.is_empty());
    }

    #[test]
    fn strength_is_skipped_and_named() {
        let strength = summary(
            source("200"),
            "Strength",
            at(6, 18),
            ActivityKind::Other,
            None,
            Some(2_400.0),
        );

        let plan = import_activities(&[strength], today(), &HashSet::new());

        assert!(plan.sessions.is_empty());
        assert_eq!(plan.skipped, vec!["Strength".to_string()]);
    }

    #[test]
    fn a_cross_country_activity_becomes_a_ski() {
        let ski = summary(
            source("300"),
            "Nordmarka",
            at(7, 10),
            ActivityKind::Ski,
            Some(12_000.0),
            Some(3_600.0),
        );

        let plan = import_activities(&[ski], today(), &HashSet::new());

        assert!(plan.skipped.is_empty());
        assert_eq!(
            plan.sessions,
            vec![PlannedSession {
                on_date: NaiveDate::from_ymd_opt(2026, 11, 7).unwrap(),
                body: SessionBody::Ski {
                    distance: 12_000,
                    duration: 3_600,
                    intervals: vec![],
                },
                source: source("300"),
            }]
        );
        let body = serde_json::to_value(&plan.sessions[0].body).unwrap();
        assert!(body.get("withPack").is_none());
    }

    #[test]
    fn an_activity_after_today_is_left_out() {
        let run = summary(
            source("400"),
            "Tomorrow",
            at(9, 8),
            ActivityKind::Run,
            Some(5_000.0),
            Some(1_500.0),
        );

        let plan = import_activities(&[run], today(), &HashSet::new());

        assert!(plan.sessions.is_empty());
        assert!(plan.skipped.is_empty());
    }

    #[test]
    fn a_run_without_a_distance_is_skipped_and_named() {
        let run = summary(
            source("500"),
            "Treadmill",
            at(6, 12),
            ActivityKind::Run,
            None,
            Some(1_200.0),
        );

        let plan = import_activities(&[run], today(), &HashSet::new());

        assert!(plan.sessions.is_empty());
        assert_eq!(plan.skipped, vec!["Treadmill".to_string()]);
    }
}
