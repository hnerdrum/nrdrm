use uuid::Uuid;

use crate::database::preset::Preset as StoredPreset;
use crate::database::session::Session as StoredSession;
use crate::domain::session::{Block, Exercise, ExerciseSet, Interval, SessionBody, Sport, Steady};
use crate::domain::source::ActivitySource;

use super::input::{BlockInput, SetInput};

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
    pub blocks: Vec<BlockInput>,
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

/// A preset in the units an agent reads back.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize, schemars::JsonSchema)]
pub struct RenderedPreset {
    pub id: Uuid,
    pub name: String,
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
    pub blocks: Vec<BlockInput>,
    pub text: String,
}

/// A body's fields in the units an agent reads, without a date.
struct BodyFields {
    sport: Sport,
    kilometres: Option<f64>,
    minutes: Option<f64>,
    pace: Option<String>,
    speed_kmh: Option<f64>,
    blocks: Vec<BlockInput>,
}

fn body_fields(body: &SessionBody) -> BodyFields {
    let sport = body.sport();
    let blocks = body.blocks().iter().map(block_input).collect();
    match body.totals() {
        None => BodyFields {
            sport,
            kilometres: None,
            minutes: None,
            pace: None,
            speed_kmh: None,
            blocks,
        },
        Some((distance, duration)) => BodyFields {
            sport,
            kilometres: Some(f64::from(distance) / 1000.0),
            minutes: Some(f64::from(duration) / 60.0),
            pace: body
                .pace()
                .map(|pace| format!("{}:{:02} /km", pace.minutes, pace.seconds)),
            speed_kmh: body.speed_kmh(),
            blocks,
        },
    }
}

pub fn render(session: &StoredSession) -> RenderedSession {
    let fields = body_fields(&session.body);
    RenderedSession {
        id: session.id,
        on_date: session.on_date,
        sport: fields.sport.as_str().to_string(),
        kilometres: fields.kilometres,
        minutes: fields.minutes,
        pace: fields.pace,
        speed_kmh: fields.speed_kmh,
        blocks: fields.blocks,
        source: session.source.as_ref().map(rendered_source),
        text: describe(session),
    }
}

pub fn render_preset(preset: &StoredPreset) -> RenderedPreset {
    let fields = body_fields(&preset.body);
    let lead = format!("Preset \"{}\", {}", preset.name, fields.sport.as_str());
    RenderedPreset {
        id: preset.id,
        name: preset.name.clone(),
        sport: fields.sport.as_str().to_string(),
        kilometres: fields.kilometres,
        minutes: fields.minutes,
        pace: fields.pace,
        speed_kmh: fields.speed_kmh,
        blocks: fields.blocks,
        text: describe_body(&lead, &preset.body),
    }
}

fn describe(session: &StoredSession) -> String {
    let name = match session.body.sport() {
        Sport::Run => "Run",
        Sport::Ride => "Ride",
        Sport::Ski => "Ski",
        Sport::Strength => "Strength",
    };
    let lead = format!("{name} on {}", session.on_date);
    let mut text = describe_body(&lead, &session.body);
    if session.source.is_some() {
        text.push(' ');
        text.push_str("From Garmin.");
    }
    text
}

/// `lead` names what the body belongs to, such as "Run on 2026-11-08".
fn describe_body(lead: &str, body: &SessionBody) -> String {
    match body.totals() {
        None => describe_strength(lead, body.blocks()),
        Some((distance, duration)) => describe_distance(lead, body, distance, duration),
    }
}

fn describe_distance(lead: &str, body: &SessionBody, distance: u32, duration: u32) -> String {
    let mut text = format!(
        "{lead}, {} km in {}",
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
    if !body.blocks().is_empty() {
        let blocks = body
            .blocks()
            .iter()
            .map(format_block)
            .collect::<Vec<_>>()
            .join("; ");
        text.push(' ');
        text.push_str(&blocks);
        text.push('.');
    }
    text
}

fn describe_strength(lead: &str, blocks: &[Block]) -> String {
    let work = blocks
        .iter()
        .map(format_block)
        .collect::<Vec<_>>()
        .join(". ");
    if work.is_empty() {
        format!("{lead}.")
    } else {
        format!("{lead}: {work}.")
    }
}

fn format_block(block: &Block) -> String {
    match block {
        Block::Steady(steady) => format_steady(steady),
        Block::Repeats(interval) => format_interval(interval),
        Block::Exercise(exercise) => format_exercise(exercise),
    }
}

fn format_steady(steady: &Steady) -> String {
    let name = steady.name.as_deref().map(str::trim).unwrap_or("steady");
    match (steady.distance >= 1, steady.duration >= 1) {
        (true, true) => format!(
            "{name} {} km in {}",
            format_km(steady.distance),
            format_duration(steady.duration)
        ),
        (true, false) => format!("{name} {} km", format_km(steady.distance)),
        (false, true) => format!("{name} {}", format_duration(steady.duration)),
        (false, false) => name.to_string(),
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

fn block_input(block: &Block) -> BlockInput {
    match block {
        Block::Steady(steady) => BlockInput::Steady {
            name: steady.name.clone(),
            distance_km: (steady.distance >= 1).then(|| f64::from(steady.distance) / 1000.0),
            minutes: (steady.duration >= 1).then(|| f64::from(steady.duration) / 60.0),
        },
        Block::Repeats(interval) => BlockInput::Repeats {
            repetitions: interval.repetitions,
            distance_m: interval.distance,
            seconds: interval.duration,
            recovery_seconds: interval.recovery,
        },
        Block::Exercise(exercise) => BlockInput::Exercise {
            name: exercise.name.clone(),
            sets: exercise.sets.iter().map(set_input).collect(),
        },
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
    use crate::domain::session::{Block, Exercise, ExerciseSet, Interval, SessionBody};
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
                blocks: vec![],
            },
            None,
        ));
        assert_eq!(rendered.sport, "run");
        assert_eq!(rendered.kilometres, Some(10.0));
        assert_eq!(rendered.minutes, Some(57.0));
        assert_eq!(rendered.pace.as_deref(), Some("5:42 /km"));
        assert_eq!(rendered.speed_kmh, None);
        assert!(rendered.blocks.is_empty());
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
                blocks: vec![],
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
                blocks: vec![
                    Block::Repeats(Interval {
                        repetitions: 4,
                        distance: 1000,
                        duration: 220,
                        recovery: 90,
                    }),
                    Block::Repeats(Interval {
                        repetitions: 4,
                        distance: 400,
                        duration: 80,
                        recovery: 60,
                    }),
                ],
            },
            None,
        ));
        assert!((rendered.kilometres.unwrap() - 5.6).abs() < 1e-9);
        assert_eq!(rendered.minutes, Some(27.5));
        assert_eq!(rendered.pace.as_deref(), Some("4:55 /km"));
        assert_eq!(rendered.blocks.len(), 2);
        assert_eq!(
            rendered.blocks[0],
            BlockInput::Repeats {
                repetitions: 4,
                distance_m: 1000,
                seconds: 220,
                recovery_seconds: 90,
            }
        );
        assert_eq!(
            rendered.text,
            "Run on 2026-11-08, 5.6 km in 27:30, 4:55 /km. 4 × 1000 m in 3:40, 1:30 rest; 4 × 400 m in 1:20, 1:00 rest."
        );
    }

    #[test]
    fn a_strength_session_reads_back_its_lifts() {
        let rendered = render(&stored(
            SessionBody::Strength {
                blocks: vec![
                    Block::Exercise(Exercise {
                        name: "squat".into(),
                        sets: vec![ExerciseSet::Reps {
                            reps: 5,
                            weight: 100.0,
                        }],
                    }),
                    Block::Exercise(Exercise {
                        name: "plank".into(),
                        sets: vec![ExerciseSet::Hold { duration: 45 }],
                    }),
                    Block::Exercise(Exercise {
                        name: "pull-up".into(),
                        sets: vec![ExerciseSet::Reps {
                            reps: 8,
                            weight: 0.0,
                        }],
                    }),
                ],
            },
            None,
        ));
        assert_eq!(rendered.sport, "strength");
        assert_eq!(rendered.kilometres, None);
        assert_eq!(rendered.minutes, None);
        assert_eq!(rendered.blocks.len(), 3);
        let set = |index: usize| match &rendered.blocks[index] {
            BlockInput::Exercise { sets, .. } => sets[0],
            other => panic!("{other:?}"),
        };
        assert_eq!(set(0).weight_kg, Some(100.0));
        assert_eq!(set(2).weight_kg, None);
        assert_eq!(set(1).hold_seconds, Some(45));
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
                blocks: vec![],
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

    fn preset(name: &str, body: SessionBody) -> StoredPreset {
        StoredPreset {
            id: Uuid::nil(),
            name: name.to_string(),
            body,
        }
    }

    #[test]
    fn an_interval_preset_reads_back_without_a_date() {
        let rendered = render_preset(&preset(
            "Thousands",
            SessionBody::Run {
                distance: 6_000,
                duration: 1_770,
                blocks: vec![Block::Repeats(Interval {
                    repetitions: 6,
                    distance: 1_000,
                    duration: 220,
                    recovery: 90,
                })],
            },
        ));
        assert_eq!(rendered.name, "Thousands");
        assert_eq!(rendered.sport, "run");
        assert_eq!(rendered.kilometres, Some(6.0));
        assert_eq!(rendered.minutes, Some(29.5));
        assert_eq!(
            rendered.blocks,
            vec![BlockInput::Repeats {
                repetitions: 6,
                distance_m: 1_000,
                seconds: 220,
                recovery_seconds: 90,
            }]
        );
        assert_eq!(
            rendered.text,
            "Preset \"Thousands\", run, 6 km in 29:30, 4:55 /km. 6 × 1000 m in 3:40, 1:30 rest."
        );
    }

    #[test]
    fn a_strength_preset_reads_back_its_lifts() {
        let rendered = render_preset(&preset(
            "Lower body",
            SessionBody::Strength {
                blocks: vec![
                    Block::Exercise(Exercise {
                        name: "squat".into(),
                        sets: vec![
                            ExerciseSet::Reps {
                                reps: 5,
                                weight: 100.0
                            };
                            2
                        ],
                    }),
                    Block::Exercise(Exercise {
                        name: "plank".into(),
                        sets: vec![ExerciseSet::Hold { duration: 45 }],
                    }),
                ],
            },
        ));
        assert_eq!(rendered.sport, "strength");
        assert_eq!(rendered.kilometres, None);
        assert_eq!(rendered.blocks.len(), 2);
        assert_eq!(
            rendered.text,
            "Preset \"Lower body\", strength: squat 5 × 100 kg, 5 × 100 kg. plank 45s."
        );
    }

    #[test]
    fn steady_blocks_read_back_in_order_around_the_repeats() {
        use crate::domain::session::Steady;
        let rendered = render(&stored(
            SessionBody::Run {
                distance: 11_200,
                duration: 3_300,
                blocks: vec![
                    Block::Steady(Steady {
                        duration: 900,
                        name: Some("warmup".into()),
                        ..Steady::default()
                    }),
                    Block::Repeats(Interval {
                        repetitions: 5,
                        distance: 1_000,
                        duration: 210,
                        recovery: 90,
                    }),
                    Block::Steady(Steady {
                        distance: 2_000,
                        duration: 600,
                        name: None,
                    }),
                ],
            },
            None,
        ));
        assert!(
            rendered
                .text
                .ends_with("warmup 15 min; 5 × 1000 m in 3:30, 1:30 rest; steady 2 km in 10 min."),
            "{}",
            rendered.text
        );
        assert_eq!(
            rendered.blocks,
            vec![
                BlockInput::Steady {
                    name: Some("warmup".into()),
                    distance_km: None,
                    minutes: Some(15.0),
                },
                BlockInput::Repeats {
                    repetitions: 5,
                    distance_m: 1_000,
                    seconds: 210,
                    recovery_seconds: 90,
                },
                BlockInput::Steady {
                    name: None,
                    distance_km: Some(2.0),
                    minutes: Some(10.0),
                },
            ]
        );
        let json = serde_json::to_value(&rendered.blocks[0]).unwrap();
        assert_eq!(
            json,
            serde_json::json!({ "kind": "steady", "name": "warmup", "minutes": 15.0 })
        );

        let strength = render(&stored(
            SessionBody::Strength {
                blocks: vec![
                    Block::Steady(Steady {
                        duration: 600,
                        name: Some("row".into()),
                        ..Steady::default()
                    }),
                    Block::Exercise(Exercise {
                        name: "squat".into(),
                        sets: vec![ExerciseSet::Reps {
                            reps: 5,
                            weight: 100.0,
                        }],
                    }),
                ],
            },
            None,
        ));
        assert!(
            strength.text.ends_with(": row 10 min. squat 5 × 100 kg."),
            "{}",
            strength.text
        );
        assert_eq!(strength.blocks.len(), 2);
    }
}
