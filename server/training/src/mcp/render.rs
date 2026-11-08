use uuid::Uuid;

use crate::database::session::Session as StoredSession;
use crate::domain::session::{Exercise, ExerciseSet, Interval, SessionBody, Sport};
use crate::domain::source::ActivitySource;

use super::input::{ExerciseInput, IntervalInput, SetInput};

/// A stored session in the units an agent reads back.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize, schemars::JsonSchema)]
pub struct RenderedSession {
    pub id: Uuid,
    pub on_date: chrono::NaiveDate,
    pub sport: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kilometres: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub minutes: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pace: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub speed_kmh: Option<f64>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub intervals: Vec<IntervalInput>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub exercises: Vec<ExerciseInput>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source: Option<RenderedSource>,
    pub text: String,
}

/// Where an imported session came from. A manual session has no source.
#[derive(
    Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize, schemars::JsonSchema,
)]
pub struct RenderedSource {
    pub provider: String,
    pub activity_id: String,
}

pub fn render(session: &StoredSession) -> RenderedSession {
    let sport = sport_of(&session.body);
    let (kilometres, minutes, pace, speed_kmh, intervals, exercises) = match &session.body {
        SessionBody::Strength { exercises } => (
            None,
            None,
            None,
            None,
            Vec::new(),
            exercises.iter().map(exercise_input).collect(),
        ),
        SessionBody::Run {
            distance,
            duration,
            intervals,
        }
        | SessionBody::Ride {
            distance,
            duration,
            intervals,
        }
        | SessionBody::Ski {
            distance,
            duration,
            intervals,
        } => (
            Some(f64::from(*distance) / 1000.0),
            Some(f64::from(*duration) / 60.0),
            session
                .body
                .pace()
                .map(|pace| format!("{}:{:02} /km", pace.minutes, pace.seconds)),
            session.body.speed_kmh(),
            intervals.iter().map(interval_input).collect(),
            Vec::new(),
        ),
    };

    RenderedSession {
        id: session.id,
        on_date: session.on_date,
        sport: sport.as_str().to_string(),
        kilometres,
        minutes,
        pace,
        speed_kmh,
        intervals,
        exercises,
        source: session.source.as_ref().map(rendered_source),
        text: describe(session),
    }
}

fn describe(session: &StoredSession) -> String {
    let mut text = match &session.body {
        SessionBody::Strength { exercises } => describe_strength(session.on_date, exercises),
        SessionBody::Run {
            distance,
            duration,
            intervals,
        }
        | SessionBody::Ride {
            distance,
            duration,
            intervals,
        }
        | SessionBody::Ski {
            distance,
            duration,
            intervals,
        } => describe_distance(
            &session.body,
            session.on_date,
            *distance,
            *duration,
            intervals,
        ),
    };
    if session.source.is_some() {
        text.push(' ');
        text.push_str("From Garmin.");
    }
    text
}

fn describe_distance(
    body: &SessionBody,
    on_date: chrono::NaiveDate,
    distance: u32,
    duration: u32,
    intervals: &[Interval],
) -> String {
    let name = match sport_of(body) {
        Sport::Run => "Run",
        Sport::Ride => "Ride",
        Sport::Ski => "Ski",
        Sport::Strength => "Strength",
    };
    let mut text = format!(
        "{name} on {on_date}, {} km in {}",
        format_km(distance),
        format_duration(duration),
    );
    if let Some(pace) = body.pace() {
        text.push_str(&format!(", {}:{:02} /km", pace.minutes, pace.seconds));
    }
    if let Some(speed) = body.speed_kmh() {
        text.push_str(&format!(", {} km/h", format_number(speed)));
    }
    text.push('.');
    if !intervals.is_empty() {
        let repeats = intervals
            .iter()
            .map(format_interval)
            .collect::<Vec<_>>()
            .join("; ");
        text.push(' ');
        text.push_str(&repeats);
        text.push('.');
    }
    text
}

fn describe_strength(on_date: chrono::NaiveDate, exercises: &[Exercise]) -> String {
    let work = exercises
        .iter()
        .map(format_exercise)
        .collect::<Vec<_>>()
        .join(". ");
    if work.is_empty() {
        format!("Strength on {on_date}.")
    } else {
        format!("Strength on {on_date}: {work}.")
    }
}

fn format_exercise(exercise: &Exercise) -> String {
    let sets = exercise
        .sets
        .iter()
        .map(format_set)
        .collect::<Vec<_>>()
        .join(", ");
    if sets.is_empty() {
        exercise.name.clone()
    } else {
        format!("{} {sets}", exercise.name)
    }
}

fn format_set(set: &ExerciseSet) -> String {
    match set {
        ExerciseSet::Reps { reps, weight } if *weight == 0.0 => format!("{reps}"),
        ExerciseSet::Reps { reps, weight } => format!("{reps} × {} kg", format_number(*weight)),
        ExerciseSet::Hold { duration } => format_hold(*duration),
    }
}

fn format_interval(interval: &Interval) -> String {
    let repetitions = interval.repetitions;
    let work = match (interval.distance >= 1, interval.duration >= 1) {
        (true, true) => format!(
            "{repetitions} × {} m in {}",
            interval.distance,
            format_clock(interval.duration)
        ),
        (true, false) => format!("{repetitions} × {} m", interval.distance),
        (false, true) => format!("{repetitions} × {}", format_clock(interval.duration)),
        (false, false) => format!("{repetitions} ×"),
    };
    if interval.recovery >= 1 {
        format!("{work}, {} rest", format_clock(interval.recovery))
    } else {
        work
    }
}

fn format_hold(seconds: u32) -> String {
    if seconds > 0 && seconds < 60 {
        format!("{seconds}s")
    } else {
        format_clock(seconds)
    }
}

fn format_duration(seconds: u32) -> String {
    let minutes = seconds / 60;
    let rest = seconds % 60;
    if rest == 0 {
        format!("{minutes} min")
    } else {
        format_clock(seconds)
    }
}

fn format_clock(seconds: u32) -> String {
    format!("{}:{:02}", seconds / 60, seconds % 60)
}

fn format_km(metres: u32) -> String {
    let whole = metres / 1000;
    let fraction = metres % 1000;
    if fraction == 0 {
        return whole.to_string();
    }
    format!("{whole}.{fraction:03}")
        .trim_end_matches('0')
        .to_string()
}

fn format_number(value: f64) -> String {
    format!("{value:.3}")
        .trim_end_matches('0')
        .trim_end_matches('.')
        .to_string()
}

fn sport_of(body: &SessionBody) -> Sport {
    match body {
        SessionBody::Run { .. } => Sport::Run,
        SessionBody::Ride { .. } => Sport::Ride,
        SessionBody::Ski { .. } => Sport::Ski,
        SessionBody::Strength { .. } => Sport::Strength,
    }
}

fn interval_input(interval: &Interval) -> IntervalInput {
    IntervalInput {
        repetitions: interval.repetitions,
        distance_m: interval.distance,
        seconds: interval.duration,
        recovery_seconds: interval.recovery,
    }
}

fn exercise_input(exercise: &Exercise) -> ExerciseInput {
    ExerciseInput {
        name: exercise.name.clone(),
        sets: exercise.sets.iter().map(set_input).collect(),
    }
}

fn set_input(set: &ExerciseSet) -> SetInput {
    match set {
        ExerciseSet::Reps { reps, weight } => SetInput {
            reps: Some(*reps),
            weight_kg: (*weight != 0.0).then_some(*weight),
            hold_seconds: None,
        },
        ExerciseSet::Hold { duration } => SetInput {
            reps: None,
            weight_kg: None,
            hold_seconds: Some(*duration),
        },
    }
}

fn rendered_source(source: &ActivitySource) -> RenderedSource {
    RenderedSource {
        provider: source.provider.as_str().to_string(),
        activity_id: source.activity_id.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session::{Exercise, ExerciseSet, Interval, SessionBody};
    use crate::domain::source::ActivityProvider;
    use chrono::NaiveDate;

    fn date(year: i32, month: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(year, month, day).unwrap()
    }

    fn stored(body: SessionBody, source: Option<ActivitySource>) -> StoredSession {
        StoredSession {
            id: Uuid::nil(),
            on_date: date(2026, 11, 8),
            body,
            source,
        }
    }

    #[test]
    fn a_run_reads_back_in_kilometres_minutes_and_pace() {
        let rendered = render(&stored(
            SessionBody::Run {
                distance: 10_000,
                duration: 3_420,
                intervals: vec![],
            },
            None,
        ));
        assert_eq!(rendered.sport, "run");
        assert_eq!(rendered.kilometres, Some(10.0));
        assert_eq!(rendered.minutes, Some(57.0));
        assert_eq!(rendered.pace.as_deref(), Some("5:42 /km"));
        assert_eq!(rendered.speed_kmh, None);
        assert!(rendered.intervals.is_empty());
        assert_eq!(
            rendered.text,
            "Run on 2026-11-08, 10 km in 57 min, 5:42 /km."
        );
    }

    #[test]
    fn a_ride_reads_back_its_speed() {
        let rendered = render(&stored(
            SessionBody::Ride {
                distance: 36_000,
                duration: 3_600,
                intervals: vec![],
            },
            None,
        ));
        assert_eq!(rendered.sport, "ride");
        assert_eq!(rendered.pace, None);
        assert_eq!(rendered.speed_kmh, Some(36.0));
        assert_eq!(
            rendered.text,
            "Ride on 2026-11-08, 36 km in 60 min, 36 km/h."
        );
    }

    #[test]
    fn an_interval_session_reads_back_its_repeats() {
        let rendered = render(&stored(
            SessionBody::Run {
                distance: 5_600,
                duration: 1_650,
                intervals: vec![
                    Interval {
                        repetitions: 4,
                        distance: 1000,
                        duration: 220,
                        recovery: 90,
                    },
                    Interval {
                        repetitions: 4,
                        distance: 400,
                        duration: 80,
                        recovery: 60,
                    },
                ],
            },
            None,
        ));
        assert!((rendered.kilometres.unwrap() - 5.6).abs() < 1e-9);
        assert_eq!(rendered.minutes, Some(27.5));
        assert_eq!(rendered.pace.as_deref(), Some("4:55 /km"));
        assert_eq!(rendered.intervals.len(), 2);
        assert_eq!(rendered.intervals[0].distance_m, 1000);
        assert_eq!(rendered.intervals[0].recovery_seconds, 90);
        assert_eq!(
            rendered.text,
            "Run on 2026-11-08, 5.6 km in 27:30, 4:55 /km. 4 × 1000 m in 3:40, 1:30 rest; 4 × 400 m in 1:20, 1:00 rest."
        );
    }

    #[test]
    fn a_strength_session_reads_back_its_lifts() {
        let rendered = render(&stored(
            SessionBody::Strength {
                exercises: vec![
                    Exercise {
                        name: "squat".into(),
                        sets: vec![ExerciseSet::Reps {
                            reps: 5,
                            weight: 100.0,
                        }],
                    },
                    Exercise {
                        name: "plank".into(),
                        sets: vec![ExerciseSet::Hold { duration: 45 }],
                    },
                    Exercise {
                        name: "pull-up".into(),
                        sets: vec![ExerciseSet::Reps {
                            reps: 8,
                            weight: 0.0,
                        }],
                    },
                ],
            },
            None,
        ));
        assert_eq!(rendered.sport, "strength");
        assert_eq!(rendered.kilometres, None);
        assert_eq!(rendered.minutes, None);
        assert_eq!(rendered.exercises.len(), 3);
        assert_eq!(rendered.exercises[0].sets[0].weight_kg, Some(100.0));
        assert_eq!(rendered.exercises[2].sets[0].weight_kg, None);
        assert_eq!(rendered.exercises[1].sets[0].hold_seconds, Some(45));
        assert_eq!(
            rendered.text,
            "Strength on 2026-11-08: squat 5 × 100 kg. plank 45s. pull-up 8."
        );
    }

    #[test]
    fn a_garmin_session_names_its_source() {
        let rendered = render(&stored(
            SessionBody::Ski {
                distance: 12_000,
                duration: 3_600,
                intervals: vec![],
            },
            Some(ActivitySource {
                provider: ActivityProvider::Garmin,
                activity_id: "123".into(),
            }),
        ));
        let source = rendered
            .source
            .expect("an imported session names its source");
        assert_eq!(source.provider, "garmin");
        assert_eq!(source.activity_id, "123");
        assert_eq!(
            rendered.text,
            "Ski on 2026-11-08, 12 km in 60 min, 5:00 /km. From Garmin."
        );
    }
}
