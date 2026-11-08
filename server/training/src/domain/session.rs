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
    Run {
        distance: u32,
        duration: u32,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        intervals: Vec<Interval>,
    },
    Ride {
        distance: u32,
        duration: u32,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        intervals: Vec<Interval>,
    },
    Ski {
        distance: u32,
        duration: u32,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        intervals: Vec<Interval>,
    },
    Strength {
        exercises: Vec<Exercise>,
    },
}

/// One block of repeats in a run, ride, or ski.
///
/// `duration` is the time of a single repeat, in seconds. `recovery` is the
/// rest between repeats, in seconds. The rest after the last repeat is not
/// part of the block, so the session time is the work plus the rests between
/// repeats. `distance` and `duration` on the session are those totals.
/// An empty list is a steady session and is omitted from JSON.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Interval {
    pub repetitions: u32,
    pub distance: u32,
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

fn is_bodyweight(weight: &f64) -> bool {
    *weight == 0.0
}

fn is_zero(value: &u32) -> bool {
    *value == 0
}

fn interval_ok(interval: &Interval) -> bool {
    interval.repetitions >= 1 && interval.distance >= 1 && interval.duration >= 1
}

fn interval_totals(intervals: &[Interval]) -> Option<(u32, u32)> {
    let mut distance = 0u32;
    let mut duration = 0u32;
    for interval in intervals {
        let work_distance = interval.repetitions.checked_mul(interval.distance)?;
        distance = distance.checked_add(work_distance)?;
        let work = interval.repetitions.checked_mul(interval.duration)?;
        let rests = interval
            .repetitions
            .saturating_sub(1)
            .checked_mul(interval.recovery)?;
        duration = duration.checked_add(work)?.checked_add(rests)?;
    }
    Some((distance, duration))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Pace {
    pub minutes: u32,
    pub seconds: u32,
}

impl SessionBody {
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
        match self {
            Self::Strength { exercises } => {
                let ok = exercises.iter().all(|exercise| {
                    exercise.sets.iter().all(|set| match set {
                        ExerciseSet::Reps { reps, weight } => {
                            *reps >= 1 && weight.is_finite() && *weight >= 0.0
                        }
                        ExerciseSet::Hold { duration } => *duration >= 1,
                    })
                });
                if ok {
                    None
                } else {
                    Some("Each set needs reps or a duration")
                }
            }
            Self::Run {
                distance,
                duration,
                intervals,
            }
            | Self::Ride {
                distance,
                duration,
                intervals,
            }
            | Self::Ski {
                distance,
                duration,
                intervals,
            } if !intervals.is_empty() => {
                let totals = interval_totals(intervals);
                let ok =
                    intervals.iter().all(interval_ok) && totals == Some((*distance, *duration));
                if ok {
                    None
                } else {
                    Some("Each interval needs repeats, a distance, and a time")
                }
            }
            _ => None,
        }
    }

    pub fn accepted(&self) -> bool {
        self.rejection().is_none()
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
            intervals: vec![],
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
            intervals: vec![],
        };
        assert_eq!(stopped.pace(), None);

        let strength = SessionBody::Strength { exercises: vec![] };
        assert_eq!(strength.pace(), None);
        assert_eq!(strength.speed_kmh(), None);

        let ride = SessionBody::Ride {
            distance: 1_000,
            duration: 0,
            intervals: vec![],
        };
        assert_eq!(ride.speed_kmh(), None);
        assert_eq!(ride.pace(), None);
    }

    #[test]
    fn ride_speed_is_kilometres_per_hour() {
        let ride = SessionBody::Ride {
            distance: 36_000,
            duration: 3_600,
            intervals: vec![],
        };
        let speed = ride.speed_kmh().expect("a ride has a speed");
        assert!((speed - 36.0).abs() < 1e-9, "{speed}");
    }

    #[test]
    fn pace_rounds_to_the_nearest_second() {
        let run = SessionBody::Run {
            distance: 2_000,
            duration: 1_001,
            intervals: vec![],
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
            intervals: vec![],
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
                duration: 1500,
                intervals: vec![],
            }
        );

        let ride: SessionBody =
            serde_json::from_str(r#"{"sport":"ride","distance":40000,"duration":3600}"#).unwrap();
        assert_eq!(
            ride,
            SessionBody::Ride {
                distance: 40000,
                duration: 3600,
                intervals: vec![],
            }
        );

        let ski: SessionBody =
            serde_json::from_str(r#"{"sport":"ski","distance":12000,"duration":3600}"#).unwrap();
        assert_eq!(
            ski,
            SessionBody::Ski {
                distance: 12000,
                duration: 3600,
                intervals: vec![],
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

    #[test]
    fn a_steady_run_omits_intervals() {
        let json = r#"{"sport":"run","distance":5000,"duration":1500}"#;
        let run: SessionBody = serde_json::from_str(json).unwrap();
        assert!(run.accepted());
        let stored = serde_json::to_value(&run).unwrap();
        assert!(stored.get("intervals").is_none());
    }

    #[test]
    fn an_interval_run_is_repeats_of_a_distance() {
        // 4 × 1000m in 3:40, 90s between, then 4 × 400m in 80s, 60s between.
        // 4*1000 + 4*400 = 5600m. Work 4*220 + 4*80, rests 3*90 + 3*60 = 1650s.
        let json = r#"{"sport":"run","distance":5600,"duration":1650,"intervals":[{"repetitions":4,"distance":1000,"duration":220,"recovery":90},{"repetitions":4,"distance":400,"duration":80,"recovery":60}]}"#;
        let run: SessionBody = serde_json::from_str(json).unwrap();
        assert!(run.accepted());
        assert_eq!(
            run,
            SessionBody::Run {
                distance: 5600,
                duration: 1650,
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
            }
        );
        let stored = serde_json::to_value(&run).unwrap();
        assert!(stored["intervals"][0].get("recovery").is_some());

        for sport in ["ride", "ski"] {
            let json = format!(
                r#"{{"sport":"{sport}","distance":5600,"duration":1650,"intervals":[{{"repetitions":4,"distance":1000,"duration":220,"recovery":90}},{{"repetitions":4,"distance":400,"duration":80,"recovery":60}}]}}"#
            );
            let body: SessionBody = serde_json::from_str(&json).unwrap();
            assert!(body.accepted(), "{sport}");
        }

        let short: SessionBody = serde_json::from_str(
            r#"{"sport":"run","distance":1000,"duration":220,"intervals":[{"repetitions":4,"distance":1000,"duration":220,"recovery":90}]}"#,
        )
        .unwrap();
        assert!(!short.accepted());
        assert_eq!(
            short.rejection(),
            Some("Each interval needs repeats, a distance, and a time")
        );

        let broken: SessionBody = serde_json::from_str(
            r#"{"sport":"run","distance":0,"duration":0,"intervals":[{"repetitions":0,"distance":400,"duration":90}]}"#,
        )
        .unwrap();
        assert!(!broken.accepted());

        let extra = serde_json::from_str::<SessionBody>(
            r#"{"sport":"run","distance":400,"duration":90,"intervals":[{"repetitions":1,"distance":400,"duration":90,"note":"fast"}]}"#,
        );
        assert!(extra.is_err());
    }
}
