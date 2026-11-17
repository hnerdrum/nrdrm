use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq)]
pub struct Session {
    pub on_date: NaiveDate,
    pub body: SessionBody,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Sport {
    Run,
    Ride,
    Ski,
    Strength,
}

impl Sport {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Run => "run",
            Self::Ride => "ride",
            Self::Ski => "ski",
            Self::Strength => "strength",
        }
    }
}

/// A sport and, for a run, ride or ski, the distance in metres and the time
/// in seconds the session took, plus its blocks in order.
///
/// The distance and time are what was done, often from the watch. Blocks
/// outline it and may add up to less, never more. A body with no blocks is a
/// steady session (or a strength session with nothing logged yet), and
/// `blocks` is omitted from JSON when empty.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(
    tag = "sport",
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
pub enum SessionBody {
    Run {
        distance: u32,
        duration: u32,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        blocks: Vec<Block>,
    },
    Ride {
        distance: u32,
        duration: u32,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        blocks: Vec<Block>,
    },
    Ski {
        distance: u32,
        duration: u32,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        blocks: Vec<Block>,
    },
    Strength {
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        blocks: Vec<Block>,
    },
}

/// One part of a session body, tagged by `kind`. A run, ride or ski takes
/// steady and repeats blocks; a strength session takes steady and exercise
/// blocks.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum Block {
    Steady(Steady),
    Repeats(Interval),
    Exercise(Exercise),
}

/// A steady stretch: a warmup, a cooldown, easy or tempo running, ten
/// minutes on the rower. `distance` is metres and `duration` seconds; it
/// needs one of them and may have both, and either is omitted from JSON when
/// zero. `name` is free text; the web and the agent use `warmup` and
/// `cooldown` for those.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Steady {
    #[serde(default, skip_serializing_if = "is_zero")]
    pub distance: u32,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub duration: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

/// One block of repeats in a run, ride, or ski.
///
/// `distance` is the metres of one repeat, and `duration` is its time in
/// seconds. A repeat needs one of them, and may have both. Either is omitted
/// from JSON when it is zero. `recovery` is the rest between repeats, in
/// seconds, and counts toward the block time when the repeat has a time.
/// The rest after the last repeat is not part of the block.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Interval {
    pub repetitions: u32,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub distance: u32,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub duration: u32,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub recovery: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Exercise {
    pub name: String,
    pub sets: Vec<ExerciseSet>,
}

/// A loaded or bodyweight effort, or a timed hold such as a plank.
/// Bodyweight is a rep set whose weight is omitted.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(untagged)]
pub enum ExerciseSet {
    Reps {
        reps: u32,
        #[serde(default, skip_serializing_if = "is_bodyweight")]
        weight: f64,
    },
    Hold {
        duration: u32,
    },
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct RawSet {
    #[serde(default)]
    reps: Option<u32>,
    #[serde(default)]
    weight: Option<f64>,
    #[serde(default)]
    duration: Option<u32>,
}

impl<'de> Deserialize<'de> for ExerciseSet {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let raw = RawSet::deserialize(deserializer)?;
        let weight = raw.weight.unwrap_or(0.0);
        match (raw.reps, raw.duration) {
            (Some(reps), None) => Ok(Self::Reps { reps, weight }),
            (None, Some(duration)) if weight == 0.0 => Ok(Self::Hold { duration }),
            _ => Err(serde::de::Error::custom("a set needs reps or a duration")),
        }
    }
}

/// The longest name a steady block may have, in characters.
pub const BLOCK_NAME_LIMIT: usize = 60;

const SET: &str = "Each set needs reps or a duration";
const INTERVAL: &str = "Each interval needs repeats, and a distance or a time";
const STEADY: &str = "Each steady block needs a distance or a time";
const BLOCK_NAME: &str = "A block name can't be blank or over 60 characters";
const REPEATS_ON_STRENGTH: &str = "Repeats belong on a run, ride or ski";
const EXERCISE_ON_DISTANCE: &str = "Exercises belong on a strength session";
const OVER_TOTALS: &str = "The blocks add up to more than the session";

fn is_bodyweight(weight: &f64) -> bool {
    *weight == 0.0
}

fn is_zero(value: &u32) -> bool {
    *value == 0
}

fn interval_ok(interval: &Interval) -> bool {
    interval.repetitions >= 1 && (interval.distance >= 1 || interval.duration >= 1)
}

fn steady_ok(steady: &Steady) -> bool {
    steady.distance >= 1 || steady.duration >= 1
}

fn name_ok(name: &Option<String>) -> bool {
    match name {
        None => true,
        Some(name) => {
            let trimmed = name.trim();
            !trimmed.is_empty() && trimmed.chars().count() <= BLOCK_NAME_LIMIT
        }
    }
}

fn set_ok(set: &ExerciseSet) -> bool {
    match set {
        ExerciseSet::Reps { reps, weight } => *reps >= 1 && weight.is_finite() && *weight >= 0.0,
        ExerciseSet::Hold { duration } => *duration >= 1,
    }
}

/// The metres and seconds the blocks account for, or `None` if that
/// overflows. A steady block adds its distance and time; repeats add their
/// work, and their recovery when the repeat has a time; an exercise adds
/// nothing.
pub fn block_totals(blocks: &[Block]) -> Option<(u32, u32)> {
    let mut distance = 0u32;
    let mut duration = 0u32;
    for block in blocks {
        match block {
            Block::Steady(steady) => {
                distance = distance.checked_add(steady.distance)?;
                duration = duration.checked_add(steady.duration)?;
            }
            Block::Repeats(interval) => {
                if interval.distance >= 1 {
                    let work = interval.repetitions.checked_mul(interval.distance)?;
                    distance = distance.checked_add(work)?;
                }
                if interval.duration >= 1 {
                    let work = interval.repetitions.checked_mul(interval.duration)?;
                    let rests = interval
                        .repetitions
                        .saturating_sub(1)
                        .checked_mul(interval.recovery)?;
                    duration = duration.checked_add(work)?.checked_add(rests)?;
                }
            }
            Block::Exercise(_) => {}
        }
    }
    Some((distance, duration))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Pace {
    pub minutes: u32,
    pub seconds: u32,
}

impl SessionBody {
    pub fn sport(&self) -> Sport {
        match self {
            Self::Run { .. } => Sport::Run,
            Self::Ride { .. } => Sport::Ride,
            Self::Ski { .. } => Sport::Ski,
            Self::Strength { .. } => Sport::Strength,
        }
    }

    pub fn blocks(&self) -> &[Block] {
        match self {
            Self::Run { blocks, .. }
            | Self::Ride { blocks, .. }
            | Self::Ski { blocks, .. }
            | Self::Strength { blocks } => blocks,
        }
    }

    /// The distance and time of a run, ride or ski.
    pub fn totals(&self) -> Option<(u32, u32)> {
        match self {
            Self::Run {
                distance, duration, ..
            }
            | Self::Ride {
                distance, duration, ..
            }
            | Self::Ski {
                distance, duration, ..
            } => Some((*distance, *duration)),
            Self::Strength { .. } => None,
        }
    }

    pub fn pace(&self) -> Option<Pace> {
        let (distance, duration) = match self {
            Self::Run {
                distance, duration, ..
            }
            | Self::Ski {
                distance, duration, ..
            } => (*distance, *duration),
            Self::Ride { .. } | Self::Strength { .. } => return None,
        };
        if distance == 0 {
            return None;
        }
        let distance = u64::from(distance);
        let seconds_per_km = (u64::from(duration) * 1000 + distance / 2) / distance;
        Some(Pace {
            minutes: (seconds_per_km / 60) as u32,
            seconds: (seconds_per_km % 60) as u32,
        })
    }

    pub fn speed_kmh(&self) -> Option<f64> {
        let Self::Ride {
            distance, duration, ..
        } = self
        else {
            return None;
        };
        if *duration == 0 {
            return None;
        }
        Some(f64::from(*distance) * 3.6 / f64::from(*duration))
    }

    pub fn rejection(&self) -> Option<&'static str> {
        let strength = self.sport() == Sport::Strength;
        for block in self.blocks() {
            let message = match block {
                Block::Steady(steady) if !steady_ok(steady) => Some(STEADY),
                Block::Steady(steady) if !name_ok(&steady.name) => Some(BLOCK_NAME),
                Block::Steady(_) => None,
                Block::Repeats(_) if strength => Some(REPEATS_ON_STRENGTH),
                Block::Repeats(interval) if !interval_ok(interval) => Some(INTERVAL),
                Block::Repeats(_) => None,
                Block::Exercise(_) if !strength => Some(EXERCISE_ON_DISTANCE),
                Block::Exercise(exercise) if !exercise.sets.iter().all(set_ok) => Some(SET),
                Block::Exercise(_) => None,
            };
            if message.is_some() {
                return message;
            }
        }
        if let Some((distance, duration)) = self.totals() {
            match block_totals(self.blocks()) {
                Some((blocks_distance, blocks_duration))
                    if blocks_distance <= distance && blocks_duration <= duration => {}
                _ => return Some(OVER_TOTALS),
            }
        }
        None
    }

    pub fn accepted(&self) -> bool {
        self.rejection().is_none()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(json: &str) -> SessionBody {
        serde_json::from_str(json).unwrap()
    }

    fn run(distance: u32, duration: u32, blocks: Vec<Block>) -> SessionBody {
        SessionBody::Run {
            distance,
            duration,
            blocks,
        }
    }

    fn repeats(repetitions: u32, distance: u32, duration: u32, recovery: u32) -> Block {
        Block::Repeats(Interval {
            repetitions,
            distance,
            duration,
            recovery,
        })
    }

    fn steady(distance: u32, duration: u32, name: Option<&str>) -> Block {
        Block::Steady(Steady {
            distance,
            duration,
            name: name.map(str::to_string),
        })
    }

    fn exercise(name: &str, sets: Vec<ExerciseSet>) -> Block {
        Block::Exercise(Exercise {
            name: name.into(),
            sets,
        })
    }

    #[test]
    fn ski_pace_is_minutes_per_kilometre() {
        let ski = SessionBody::Ski {
            distance: 15_000,
            duration: 3_600,
            blocks: vec![],
        };
        assert_eq!(
            ski.pace(),
            Some(Pace {
                minutes: 4,
                seconds: 0
            })
        );
    }

    #[test]
    fn pace_and_speed_are_absent_without_a_distance_sport() {
        assert_eq!(run(0, 1_200, vec![]).pace(), None);

        let strength = SessionBody::Strength { blocks: vec![] };
        assert_eq!(strength.pace(), None);
        assert_eq!(strength.speed_kmh(), None);

        let ride = SessionBody::Ride {
            distance: 1_000,
            duration: 0,
            blocks: vec![],
        };
        assert_eq!(ride.speed_kmh(), None);
        assert_eq!(ride.pace(), None);
    }

    #[test]
    fn ride_speed_is_kilometres_per_hour() {
        let ride = SessionBody::Ride {
            distance: 36_000,
            duration: 3_600,
            blocks: vec![],
        };
        let speed = ride.speed_kmh().expect("a ride has a speed");
        assert!((speed - 36.0).abs() < 1e-9, "{speed}");
    }

    #[test]
    fn pace_rounds_to_the_nearest_second() {
        assert_eq!(
            run(2_000, 1_001, vec![]).pace(),
            Some(Pace {
                minutes: 8,
                seconds: 21
            })
        );
        assert_eq!(
            run(10_000, 3_000, vec![]).pace(),
            Some(Pace {
                minutes: 5,
                seconds: 0
            })
        );
    }

    #[test]
    fn rejects_unknown_and_old_fields() {
        for json in [
            r#"{"sport":"strength","blocks":[],"distance":1000}"#,
            r#"{"sport":"ski","distance":12000,"duration":3600,"withPack":true}"#,
            r#"{"sport":"run","distance":5000,"duration":1500,"intervals":[]}"#,
            r#"{"sport":"strength","exercises":[]}"#,
            r#"{"sport":"run","distance":400,"duration":90,"blocks":[{"kind":"repeats","repetitions":1,"distance":400,"note":"fast"}]}"#,
            r#"{"sport":"run","distance":400,"duration":90,"blocks":[{"kind":"steady","distance":400,"pace":"fast"}]}"#,
            r#"{"sport":"run","distance":400,"duration":90,"blocks":[{"kind":"lap","distance":400}]}"#,
            r#"{"sport":"run","distance":400,"duration":90,"blocks":[{"distance":400}]}"#,
        ] {
            assert!(serde_json::from_str::<SessionBody>(json).is_err(), "{json}");
        }
    }

    #[test]
    fn parses_each_sport_body() {
        assert_eq!(
            parse(r#"{"sport":"run","distance":5000,"duration":1500}"#),
            run(5000, 1500, vec![])
        );
        assert_eq!(
            parse(r#"{"sport":"ride","distance":40000,"duration":3600}"#),
            SessionBody::Ride {
                distance: 40000,
                duration: 3600,
                blocks: vec![],
            }
        );
        assert_eq!(
            parse(r#"{"sport":"ski","distance":12000,"duration":3600}"#),
            SessionBody::Ski {
                distance: 12000,
                duration: 3600,
                blocks: vec![],
            }
        );
        assert_eq!(
            parse(
                r#"{"sport":"strength","blocks":[{"kind":"exercise","name":"squat","sets":[{"reps":5,"weight":0}]}]}"#
            ),
            SessionBody::Strength {
                blocks: vec![exercise(
                    "squat",
                    vec![ExerciseSet::Reps {
                        reps: 5,
                        weight: 0.0
                    }]
                )]
            }
        );
        assert_eq!(
            parse(r#"{"sport":"strength"}"#),
            SessionBody::Strength { blocks: vec![] }
        );
    }

    #[test]
    fn empty_blocks_are_omitted_from_json() {
        let stored = serde_json::to_value(run(5000, 1500, vec![])).unwrap();
        assert!(stored.get("blocks").is_none());
        let stored = serde_json::to_value(SessionBody::Strength { blocks: vec![] }).unwrap();
        assert_eq!(stored, serde_json::json!({ "sport": "strength" }));
    }

    #[test]
    fn a_rep_set_may_omit_its_weight() {
        let strength = parse(
            r#"{"sport":"strength","blocks":[{"kind":"exercise","name":"pull-up","sets":[{"reps":8}]}]}"#,
        );
        assert!(strength.accepted());
        assert_eq!(
            strength,
            SessionBody::Strength {
                blocks: vec![exercise(
                    "pull-up",
                    vec![ExerciseSet::Reps {
                        reps: 8,
                        weight: 0.0
                    }]
                )]
            }
        );
        let stored = serde_json::to_value(&strength).unwrap();
        assert!(stored["blocks"][0]["sets"][0].get("weight").is_none());
        assert_eq!(stored["blocks"][0]["kind"], "exercise");
    }

    #[test]
    fn a_hold_is_a_duration_in_seconds() {
        let strength = parse(
            r#"{"sport":"strength","blocks":[{"kind":"exercise","name":"plank","sets":[{"duration":45}]}]}"#,
        );
        assert!(strength.accepted());
        assert_eq!(
            strength,
            SessionBody::Strength {
                blocks: vec![exercise("plank", vec![ExerciseSet::Hold { duration: 45 }])]
            }
        );
    }

    #[test]
    fn a_set_is_either_reps_or_a_hold() {
        let both = serde_json::from_str::<SessionBody>(
            r#"{"sport":"strength","blocks":[{"kind":"exercise","name":"plank","sets":[{"reps":5,"duration":45}]}]}"#,
        );
        assert!(both.is_err());

        let empty = parse(
            r#"{"sport":"strength","blocks":[{"kind":"exercise","name":"plank","sets":[{"reps":0}]}]}"#,
        );
        assert_eq!(empty.rejection(), Some(SET));

        let zero = parse(
            r#"{"sport":"strength","blocks":[{"kind":"exercise","name":"plank","sets":[{"duration":0}]}]}"#,
        );
        assert_eq!(zero.rejection(), Some(SET));
    }

    #[test]
    fn an_interval_run_is_repeats_of_a_distance() {
        // 4 × 1000m in 3:40, 90s between, then 4 × 400m in 80s, 60s between.
        // 4*1000 + 4*400 = 5600m. Work 4*220 + 4*80, rests 3*90 + 3*60 = 1650s.
        let json = r#"{"sport":"run","distance":5600,"duration":1650,"blocks":[{"kind":"repeats","repetitions":4,"distance":1000,"duration":220,"recovery":90},{"kind":"repeats","repetitions":4,"distance":400,"duration":80,"recovery":60}]}"#;
        let body = parse(json);
        assert!(body.accepted());
        assert_eq!(
            body,
            run(
                5600,
                1650,
                vec![repeats(4, 1000, 220, 90), repeats(4, 400, 80, 60)]
            )
        );
        assert_eq!(block_totals(body.blocks()), Some((5600, 1650)));
        let stored = serde_json::to_value(&body).unwrap();
        assert_eq!(stored["blocks"][0]["kind"], "repeats");
        assert_eq!(stored["blocks"][0]["recovery"], 90);

        for sport in ["ride", "ski"] {
            let json = json.replace(r#""sport":"run""#, &format!(r#""sport":"{sport}""#));
            assert!(parse(&json).accepted(), "{sport}");
        }

        let timed = run(0, 480, vec![repeats(8, 0, 60, 0)]);
        assert!(timed.accepted());
        let timed_stored = serde_json::to_value(&timed).unwrap();
        assert!(timed_stored["blocks"][0].get("distance").is_none());

        let marked = run(2400, 0, vec![repeats(6, 400, 0, 0)]);
        assert!(marked.accepted());

        assert_eq!(
            run(400, 90, vec![repeats(0, 400, 90, 0)]).rejection(),
            Some(INTERVAL)
        );
        assert_eq!(
            run(0, 0, vec![repeats(8, 0, 0, 0)]).rejection(),
            Some(INTERVAL)
        );
    }

    #[test]
    fn a_warmup_and_cooldown_fit_inside_the_session() {
        let json = r#"{"sport":"run","distance":11200,"duration":3300,"blocks":[{"kind":"steady","duration":900,"name":"warmup"},{"kind":"repeats","repetitions":5,"distance":1000,"duration":210,"recovery":90},{"kind":"steady","duration":600,"name":"cooldown"}]}"#;
        let body = parse(json);
        assert_eq!(
            body,
            run(
                11_200,
                3_300,
                vec![
                    steady(0, 900, Some("warmup")),
                    repeats(5, 1000, 210, 90),
                    steady(0, 600, Some("cooldown")),
                ]
            )
        );
        // 900 + 5*210 + 4*90 + 600 = 2910s, 5000m: less than the session.
        assert_eq!(block_totals(body.blocks()), Some((5_000, 2_910)));
        assert!(body.accepted());
        assert_eq!(
            serde_json::to_value(&body).unwrap(),
            serde_json::from_str::<serde_json::Value>(json).unwrap()
        );

        let exact = run(5_000, 2_910, body.blocks().to_vec());
        assert!(exact.accepted());

        let short_time = run(11_200, 2_909, body.blocks().to_vec());
        assert_eq!(short_time.rejection(), Some(OVER_TOTALS));
        let short_distance = run(4_999, 3_300, body.blocks().to_vec());
        assert_eq!(short_distance.rejection(), Some(OVER_TOTALS));
    }

    #[test]
    fn a_steady_block_needs_a_distance_or_a_time_and_a_fair_name() {
        assert!(run(3_000, 900, vec![steady(3_000, 0, None)]).accepted());
        assert!(run(3_000, 900, vec![steady(0, 900, None)]).accepted());
        assert!(run(3_000, 900, vec![steady(3_000, 900, Some("tempo"))]).accepted());
        assert_eq!(
            run(3_000, 900, vec![steady(0, 0, Some("warmup"))]).rejection(),
            Some(STEADY)
        );
        assert_eq!(
            run(3_000, 900, vec![steady(0, 900, Some("  "))]).rejection(),
            Some(BLOCK_NAME)
        );
        let long = "x".repeat(BLOCK_NAME_LIMIT + 1);
        assert_eq!(
            run(3_000, 900, vec![steady(0, 900, Some(&long))]).rejection(),
            Some(BLOCK_NAME)
        );
        let stored = serde_json::to_value(steady(0, 900, None)).unwrap();
        assert_eq!(
            stored,
            serde_json::json!({ "kind": "steady", "duration": 900 })
        );
    }

    #[test]
    fn each_sport_takes_its_own_blocks() {
        let squat = exercise(
            "squat",
            vec![ExerciseSet::Reps {
                reps: 5,
                weight: 100.0,
            }],
        );
        let rower = SessionBody::Strength {
            blocks: vec![steady(2_000, 600, Some("row")), squat.clone()],
        };
        assert!(rower.accepted());
        assert_eq!(
            run(5_000, 1_500, vec![squat]).rejection(),
            Some(EXERCISE_ON_DISTANCE)
        );
        assert_eq!(
            SessionBody::Strength {
                blocks: vec![repeats(4, 400, 90, 60)]
            }
            .rejection(),
            Some(REPEATS_ON_STRENGTH)
        );
    }
}
