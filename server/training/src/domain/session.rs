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

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(
    tag = "sport",
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
pub enum SessionBody {
    Run { distance: u32, duration: u32 },
    Ride { distance: u32, duration: u32 },
    Ski { distance: u32, duration: u32 },
    Strength { exercises: Vec<Exercise> },
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

fn is_bodyweight(weight: &f64) -> bool {
    *weight == 0.0
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Pace {
    pub minutes: u32,
    pub seconds: u32,
}

impl SessionBody {
    pub fn pace(&self) -> Option<Pace> {
        let (distance, duration) = match self {
            Self::Run { distance, duration }
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
        let Self::Ride { distance, duration } = self else {
            return None;
        };
        if *duration == 0 {
            return None;
        }
        Some(f64::from(*distance) * 3.6 / f64::from(*duration))
    }

    pub fn accepted(&self) -> bool {
        let Self::Strength { exercises } = self else {
            return true;
        };
        exercises.iter().all(|exercise| {
            exercise.sets.iter().all(|set| match set {
                ExerciseSet::Reps { reps, weight } => {
                    *reps >= 1 && weight.is_finite() && *weight >= 0.0
                }
                ExerciseSet::Hold { duration } => *duration >= 1,
            })
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ski_pace_is_minutes_per_kilometre() {
        let ski = SessionBody::Ski {
            distance: 15_000,
            duration: 3_600,
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
        let stopped = SessionBody::Run {
            distance: 0,
            duration: 1_200,
        };
        assert_eq!(stopped.pace(), None);

        let strength = SessionBody::Strength { exercises: vec![] };
        assert_eq!(strength.pace(), None);
        assert_eq!(strength.speed_kmh(), None);

        let ride = SessionBody::Ride {
            distance: 1_000,
            duration: 0,
        };
        assert_eq!(ride.speed_kmh(), None);
        assert_eq!(ride.pace(), None);
    }

    #[test]
    fn ride_speed_is_kilometres_per_hour() {
        let ride = SessionBody::Ride {
            distance: 36_000,
            duration: 3_600,
        };
        let speed = ride.speed_kmh().expect("a ride has a speed");
        assert!((speed - 36.0).abs() < 1e-9, "{speed}");
    }

    #[test]
    fn pace_rounds_to_the_nearest_second() {
        let run = SessionBody::Run {
            distance: 2_000,
            duration: 1_001,
        };
        assert_eq!(
            run.pace(),
            Some(Pace {
                minutes: 8,
                seconds: 21
            })
        );
    }

    #[test]
    fn run_pace_is_minutes_per_kilometre() {
        let run = SessionBody::Run {
            distance: 10_000,
            duration: 3_000,
        };
        assert_eq!(
            run.pace(),
            Some(Pace {
                minutes: 5,
                seconds: 0
            })
        );
    }

    #[test]
    fn rejects_a_strength_body_that_includes_distance() {
        let json = r#"{"sport":"strength","exercises":[],"distance":1000}"#;
        let parsed = serde_json::from_str::<SessionBody>(json);
        assert!(parsed.is_err());
    }

    #[test]
    fn parses_each_sport_body() {
        let run: SessionBody =
            serde_json::from_str(r#"{"sport":"run","distance":5000,"duration":1500}"#).unwrap();
        assert_eq!(
            run,
            SessionBody::Run {
                distance: 5000,
                duration: 1500
            }
        );

        let ride: SessionBody =
            serde_json::from_str(r#"{"sport":"ride","distance":40000,"duration":3600}"#).unwrap();
        assert_eq!(
            ride,
            SessionBody::Ride {
                distance: 40000,
                duration: 3600
            }
        );

        let ski: SessionBody =
            serde_json::from_str(r#"{"sport":"ski","distance":12000,"duration":3600}"#).unwrap();
        assert_eq!(
            ski,
            SessionBody::Ski {
                distance: 12000,
                duration: 3600
            }
        );

        let packed = serde_json::from_str::<SessionBody>(
            r#"{"sport":"ski","distance":12000,"duration":3600,"withPack":true}"#,
        );
        assert!(packed.is_err());

        let strength: SessionBody = serde_json::from_str(
            r#"{"sport":"strength","exercises":[{"name":"squat","sets":[{"reps":5,"weight":0}]}]}"#,
        )
        .unwrap();
        assert_eq!(
            strength,
            SessionBody::Strength {
                exercises: vec![Exercise {
                    name: "squat".into(),
                    sets: vec![ExerciseSet::Reps {
                        reps: 5,
                        weight: 0.0
                    }]
                }]
            }
        );
    }

    #[test]
    fn a_rep_set_may_omit_its_weight() {
        let strength: SessionBody = serde_json::from_str(
            r#"{"sport":"strength","exercises":[{"name":"pull-up","sets":[{"reps":8}]}]}"#,
        )
        .unwrap();
        assert!(strength.accepted());
        assert_eq!(
            strength,
            SessionBody::Strength {
                exercises: vec![Exercise {
                    name: "pull-up".into(),
                    sets: vec![ExerciseSet::Reps {
                        reps: 8,
                        weight: 0.0
                    }]
                }]
            }
        );
        let stored = serde_json::to_value(&strength).unwrap();
        assert!(stored["exercises"][0]["sets"][0].get("weight").is_none());
    }

    #[test]
    fn a_hold_is_a_duration_in_seconds() {
        let strength: SessionBody = serde_json::from_str(
            r#"{"sport":"strength","exercises":[{"name":"plank","sets":[{"duration":45}]}]}"#,
        )
        .unwrap();
        assert!(strength.accepted());
        assert_eq!(
            strength,
            SessionBody::Strength {
                exercises: vec![Exercise {
                    name: "plank".into(),
                    sets: vec![ExerciseSet::Hold { duration: 45 }]
                }]
            }
        );
    }

    #[test]
    fn a_set_is_either_reps_or_a_hold() {
        let both = serde_json::from_str::<SessionBody>(
            r#"{"sport":"strength","exercises":[{"name":"plank","sets":[{"reps":5,"duration":45}]}]}"#,
        );
        assert!(both.is_err());

        let empty: SessionBody = serde_json::from_str(
            r#"{"sport":"strength","exercises":[{"name":"plank","sets":[{"reps":0}]}]}"#,
        )
        .unwrap();
        assert!(!empty.accepted());

        let zero: SessionBody = serde_json::from_str(
            r#"{"sport":"strength","exercises":[{"name":"plank","sets":[{"duration":0}]}]}"#,
        )
        .unwrap();
        assert!(!zero.accepted());
    }
}
