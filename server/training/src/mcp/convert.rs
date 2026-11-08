use chrono::NaiveDate;

use crate::clock::Clock;
use crate::domain::session::{
    interval_totals, Exercise, ExerciseSet, Interval, SessionBody, Sport,
};

use super::input::{
    DistanceSession, ExerciseInput, IntervalInput, SessionUpdate, SetInput, StrengthSession,
};

const SET: &str = "Each set needs reps or a duration";
const TOO_LONG: &str = "That session is too long to store";
const FROM_INTERVALS: &str = "This session's distance and time come from its intervals";
const STRENGTH_DISTANCE: &str = "A strength session has no distance or time";
const DISTANCE_EXERCISES: &str = "Exercises belong on a strength session";

/// A session ready to store: a date and a body the domain accepts.
#[derive(Debug, Clone, PartialEq)]
pub struct PreparedSession {
    pub on_date: NaiveDate,
    pub body: SessionBody,
}

pub fn prepare_run(
    input: &DistanceSession,
    clock: &dyn Clock,
) -> Result<PreparedSession, &'static str> {
    prepare_distance(Sport::Run, input, clock)
}

pub fn prepare_ride(
    input: &DistanceSession,
    clock: &dyn Clock,
) -> Result<PreparedSession, &'static str> {
    prepare_distance(Sport::Ride, input, clock)
}

pub fn prepare_ski(
    input: &DistanceSession,
    clock: &dyn Clock,
) -> Result<PreparedSession, &'static str> {
    prepare_distance(Sport::Ski, input, clock)
}

pub fn prepare_strength(
    input: &StrengthSession,
    clock: &dyn Clock,
) -> Result<PreparedSession, &'static str> {
    Ok(PreparedSession {
        on_date: input.on_date.unwrap_or_else(|| clock.today()),
        body: strength_body(&input.exercises)?,
    })
}

pub fn apply_update(
    on_date: NaiveDate,
    body: &SessionBody,
    update: &SessionUpdate,
) -> Result<PreparedSession, &'static str> {
    Ok(PreparedSession {
        on_date: update.on_date.unwrap_or(on_date),
        body: merge_body(body, update)?,
    })
}

fn prepare_distance(
    sport: Sport,
    input: &DistanceSession,
    clock: &dyn Clock,
) -> Result<PreparedSession, &'static str> {
    Ok(PreparedSession {
        on_date: input.on_date.unwrap_or_else(|| clock.today()),
        body: distance_from_input(sport, input)?,
    })
}

fn distance_from_input(sport: Sport, input: &DistanceSession) -> Result<SessionBody, &'static str> {
    let intervals: Vec<Interval> = input.intervals.iter().copied().map(interval).collect();
    let (distance, duration) = if input.intervals.is_empty() {
        (
            metres(input.distance_km.ok_or(needs_distance(sport))?)?,
            seconds(input.minutes.ok_or(needs_time(sport))?)?,
        )
    } else {
        // The repeats are the session. A distance or a time sent alongside
        // them has to agree, which is the check `rejection` already makes.
        let (total_distance, total_duration) = interval_totals(&intervals).ok_or(TOO_LONG)?;
        (
            match input.distance_km {
                Some(kilometres) => metres(kilometres)?,
                None => total_distance,
            },
            match input.minutes {
                Some(minutes) => seconds(minutes)?,
                None => total_duration,
            },
        )
    };
    accept(sport, distance, duration, intervals)
}

fn merge_body(body: &SessionBody, update: &SessionUpdate) -> Result<SessionBody, &'static str> {
    if let Some(stored) = distance_parts(body) {
        if update.exercises.is_some() {
            return Err(DISTANCE_EXERCISES);
        }
        return merge_distance(stored, update);
    }

    if update.distance_km.is_some() || update.minutes.is_some() || update.intervals.is_some() {
        return Err(STRENGTH_DISTANCE);
    }
    match &update.exercises {
        Some(exercises) => strength_body(exercises),
        None => Ok(body.clone()),
    }
}

fn merge_distance(
    stored: DistanceParts<'_>,
    update: &SessionUpdate,
) -> Result<SessionBody, &'static str> {
    let Some(list) = &update.intervals else {
        if !stored.intervals.is_empty()
            && (update.distance_km.is_some() || update.minutes.is_some())
        {
            return Err(FROM_INTERVALS);
        }
        return accept(
            stored.sport,
            match update.distance_km {
                Some(kilometres) => metres(kilometres)?,
                None => stored.distance,
            },
            match update.minutes {
                Some(minutes) => seconds(minutes)?,
                None => stored.duration,
            },
            stored.intervals.to_vec(),
        );
    };

    let intervals: Vec<Interval> = list.iter().copied().map(interval).collect();
    let (fallback_distance, fallback_duration) = if intervals.is_empty() {
        (stored.distance, stored.duration)
    } else {
        interval_totals(&intervals).ok_or(TOO_LONG)?
    };
    accept(
        stored.sport,
        match update.distance_km {
            Some(kilometres) => metres(kilometres)?,
            None => fallback_distance,
        },
        match update.minutes {
            Some(minutes) => seconds(minutes)?,
            None => fallback_duration,
        },
        intervals,
    )
}

fn accept(
    sport: Sport,
    distance: u32,
    duration: u32,
    intervals: Vec<Interval>,
) -> Result<SessionBody, &'static str> {
    let body = match sport {
        Sport::Run => SessionBody::Run {
            distance,
            duration,
            intervals,
        },
        Sport::Ride => SessionBody::Ride {
            distance,
            duration,
            intervals,
        },
        Sport::Ski => SessionBody::Ski {
            distance,
            duration,
            intervals,
        },
        Sport::Strength => return Err(STRENGTH_DISTANCE),
    };
    match body.rejection() {
        Some(message) => Err(message),
        None => Ok(body),
    }
}

fn strength_body(exercises: &[ExerciseInput]) -> Result<SessionBody, &'static str> {
    let exercises = exercises
        .iter()
        .map(exercise)
        .collect::<Result<Vec<_>, _>>()?;
    let body = SessionBody::Strength { exercises };
    match body.rejection() {
        Some(message) => Err(message),
        None => Ok(body),
    }
}

fn exercise(input: &ExerciseInput) -> Result<Exercise, &'static str> {
    let sets = input.sets.iter().map(set).collect::<Result<Vec<_>, _>>()?;
    Ok(Exercise {
        name: input.name.clone(),
        sets,
    })
}

fn set(input: &SetInput) -> Result<ExerciseSet, &'static str> {
    let weight = input.weight_kg.unwrap_or(0.0);
    match (input.reps, input.hold_seconds) {
        (Some(reps), None) => Ok(ExerciseSet::Reps { reps, weight }),
        (None, Some(duration)) if weight == 0.0 => Ok(ExerciseSet::Hold { duration }),
        _ => Err(SET),
    }
}

fn interval(input: IntervalInput) -> Interval {
    Interval {
        repetitions: input.repetitions,
        distance: input.distance_m,
        duration: input.seconds,
        recovery: input.recovery_seconds,
    }
}

struct DistanceParts<'a> {
    sport: Sport,
    distance: u32,
    duration: u32,
    intervals: &'a [Interval],
}

fn distance_parts(body: &SessionBody) -> Option<DistanceParts<'_>> {
    match body {
        SessionBody::Run {
            distance,
            duration,
            intervals,
        } => Some(DistanceParts {
            sport: Sport::Run,
            distance: *distance,
            duration: *duration,
            intervals,
        }),
        SessionBody::Ride {
            distance,
            duration,
            intervals,
        } => Some(DistanceParts {
            sport: Sport::Ride,
            distance: *distance,
            duration: *duration,
            intervals,
        }),
        SessionBody::Ski {
            distance,
            duration,
            intervals,
        } => Some(DistanceParts {
            sport: Sport::Ski,
            distance: *distance,
            duration: *duration,
            intervals,
        }),
        SessionBody::Strength { .. } => None,
    }
}

fn metres(kilometres: f64) -> Result<u32, &'static str> {
    whole_units(
        kilometres,
        1000.0,
        "A distance needs to be a number of kilometres",
    )
}

fn seconds(minutes: f64) -> Result<u32, &'static str> {
    whole_units(minutes, 60.0, "A time needs to be a number of minutes")
}

fn whole_units(value: f64, scale: f64, message: &'static str) -> Result<u32, &'static str> {
    if !value.is_finite() || value < 0.0 {
        return Err(message);
    }
    let rounded = (value * scale).round();
    if rounded > f64::from(u32::MAX) {
        return Err(TOO_LONG);
    }
    Ok(rounded as u32)
}

fn needs_distance(sport: Sport) -> &'static str {
    match sport {
        Sport::Run => "A run needs a distance in kilometres",
        Sport::Ride => "A ride needs a distance in kilometres",
        Sport::Ski => "A ski needs a distance in kilometres",
        Sport::Strength => STRENGTH_DISTANCE,
    }
}

fn needs_time(sport: Sport) -> &'static str {
    match sport {
        Sport::Run => "A run needs a time in minutes",
        Sport::Ride => "A ride needs a time in minutes",
        Sport::Ski => "A ski needs a time in minutes",
        Sport::Strength => STRENGTH_DISTANCE,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clock::FixedClock;
    use chrono::NaiveDate;

    fn date(year: i32, month: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(year, month, day).unwrap()
    }

    fn clock() -> FixedClock {
        FixedClock(date(2026, 11, 8))
    }

    fn steady(distance: u32, duration: u32) -> SessionBody {
        SessionBody::Run {
            distance,
            duration,
            intervals: vec![],
        }
    }

    #[test]
    fn ten_kilometres_in_fifty_seven_minutes_is_metres_and_seconds() {
        let input: DistanceSession =
            serde_json::from_str(r#"{"distance_km":10,"minutes":57}"#).unwrap();
        let prepared = prepare_run(&input, &clock()).unwrap();
        assert_eq!(prepared.on_date, date(2026, 11, 8));
        assert_eq!(prepared.body, steady(10_000, 3_420));

        let dated: DistanceSession =
            serde_json::from_str(r#"{"on_date":"2026-11-07","distance_km":10,"minutes":57}"#)
                .unwrap();
        assert_eq!(
            prepare_run(&dated, &clock()).unwrap().on_date,
            date(2026, 11, 7)
        );

        let ride = prepare_ride(&input, &clock()).unwrap().body;
        assert_eq!(
            ride,
            SessionBody::Ride {
                distance: 10_000,
                duration: 3_420,
                intervals: vec![],
            }
        );
        let ski = prepare_ski(&input, &clock()).unwrap().body;
        assert_eq!(
            ski,
            SessionBody::Ski {
                distance: 10_000,
                duration: 3_420,
                intervals: vec![],
            }
        );

        let extra = serde_json::from_str::<DistanceSession>(
            r#"{"distance_km":10,"minutes":57,"sport":"run"}"#,
        );
        assert!(extra.is_err());
    }

    #[test]
    fn fractional_units_round_to_the_nearest_metre_and_second() {
        let prepared = prepare_run(
            &DistanceSession {
                distance_km: Some(10.5),
                minutes: Some(57.5),
                ..Default::default()
            },
            &clock(),
        )
        .unwrap();
        assert_eq!(prepared.body, steady(10_500, 3_450));
    }

    #[test]
    fn a_steady_session_needs_a_distance_and_a_time() {
        let err = prepare_run(&DistanceSession::default(), &clock()).unwrap_err();
        assert_eq!(err, "A run needs a distance in kilometres");

        let minutes = prepare_ski(
            &DistanceSession {
                distance_km: Some(12.0),
                ..Default::default()
            },
            &clock(),
        )
        .unwrap_err();
        assert_eq!(minutes, "A ski needs a time in minutes");

        let negative = prepare_ride(
            &DistanceSession {
                distance_km: Some(-1.0),
                minutes: Some(30.0),
                ..Default::default()
            },
            &clock(),
        )
        .unwrap_err();
        assert_eq!(negative, "A distance needs to be a number of kilometres");
    }

    #[test]
    fn intervals_are_totalled_into_the_stored_distance_and_time() {
        // 4 × 1000m in 3:40, 90s between, then 4 × 400m in 80s, 60s between.
        // 4*1000 + 4*400 = 5600m. Work 4*220 + 4*80, rests 3*90 + 3*60 = 1650s.
        let input = DistanceSession {
            intervals: vec![
                IntervalInput {
                    repetitions: 4,
                    distance_m: 1000,
                    seconds: 220,
                    recovery_seconds: 90,
                },
                IntervalInput {
                    repetitions: 4,
                    distance_m: 400,
                    seconds: 80,
                    recovery_seconds: 60,
                },
            ],
            ..Default::default()
        };
        let prepared = prepare_run(&input, &clock()).unwrap();
        assert_eq!(
            prepared.body,
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
            }
        );

        let short = DistanceSession {
            distance_km: Some(1.0),
            ..input
        };
        assert_eq!(
            prepare_run(&short, &clock()).unwrap_err(),
            "Each interval needs repeats, and a distance or a time"
        );
    }

    #[test]
    fn a_broken_interval_returns_the_domain_message() {
        let input = DistanceSession {
            intervals: vec![IntervalInput {
                repetitions: 0,
                distance_m: 400,
                seconds: 90,
                recovery_seconds: 0,
            }],
            ..Default::default()
        };
        assert_eq!(
            prepare_run(&input, &clock()).unwrap_err(),
            "Each interval needs repeats, and a distance or a time"
        );
    }

    #[test]
    fn a_strength_session_stores_reps_weight_and_holds() {
        let input: StrengthSession = serde_json::from_str(
            r#"{"exercises":[{"name":"squat","sets":[{"reps":5,"weight_kg":100}]},{"name":"plank","sets":[{"hold_seconds":45}]},{"name":"pull-up","sets":[{"reps":8}]}]}"#,
        )
        .unwrap();
        let prepared = prepare_strength(&input, &clock()).unwrap();
        assert_eq!(prepared.on_date, date(2026, 11, 8));
        assert_eq!(
            prepared.body,
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
            }
        );
    }

    #[test]
    fn a_bad_set_returns_the_domain_message() {
        let zero = StrengthSession {
            exercises: vec![ExerciseInput {
                name: "squat".into(),
                sets: vec![SetInput {
                    reps: Some(0),
                    ..Default::default()
                }],
            }],
            ..Default::default()
        };
        assert_eq!(
            prepare_strength(&zero, &clock()).unwrap_err(),
            "Each set needs reps or a duration"
        );

        let both = StrengthSession {
            exercises: vec![ExerciseInput {
                name: "plank".into(),
                sets: vec![SetInput {
                    reps: Some(5),
                    hold_seconds: Some(45),
                    ..Default::default()
                }],
            }],
            ..Default::default()
        };
        assert_eq!(
            prepare_strength(&both, &clock()).unwrap_err(),
            "Each set needs reps or a duration"
        );
    }

    #[test]
    fn a_duration_only_update_leaves_the_distance_alone() {
        let date = date(2026, 11, 8);
        let updated = apply_update(
            date,
            &steady(10_000, 3_420),
            &SessionUpdate {
                minutes: Some(58.0),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(updated.on_date, date);
        assert_eq!(updated.body, steady(10_000, 3_480));
    }

    #[test]
    fn a_date_change_leaves_the_body() {
        let stored = steady(10_000, 3_420);
        let updated = apply_update(
            date(2026, 11, 8),
            &stored,
            &SessionUpdate {
                on_date: Some(date(2026, 11, 7)),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(updated.on_date, date(2026, 11, 7));
        assert_eq!(updated.body, stored);
    }

    #[test]
    fn changing_the_time_of_an_interval_session_goes_through_the_intervals() {
        let stored = SessionBody::Run {
            distance: 4_000,
            duration: 1_150,
            intervals: vec![Interval {
                repetitions: 4,
                distance: 1000,
                duration: 220,
                recovery: 90,
            }],
        };
        let err = apply_update(
            date(2026, 11, 8),
            &stored,
            &SessionUpdate {
                minutes: Some(20.0),
                ..Default::default()
            },
        )
        .unwrap_err();
        assert_eq!(err, FROM_INTERVALS);

        let cleared = apply_update(
            date(2026, 11, 8),
            &stored,
            &SessionUpdate {
                intervals: Some(vec![]),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(cleared.body, steady(4_000, 1_150));
    }

    #[test]
    fn the_sport_stays_the_same() {
        let date = date(2026, 11, 8);
        let strength = SessionBody::Strength {
            exercises: vec![Exercise {
                name: "squat".into(),
                sets: vec![ExerciseSet::Reps {
                    reps: 5,
                    weight: 100.0,
                }],
            }],
        };
        let updated = apply_update(
            date,
            &strength,
            &SessionUpdate {
                exercises: Some(vec![ExerciseInput {
                    name: "bench".into(),
                    sets: vec![SetInput {
                        reps: Some(8),
                        weight_kg: Some(60.0),
                        ..Default::default()
                    }],
                }]),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(
            updated.body,
            SessionBody::Strength {
                exercises: vec![Exercise {
                    name: "bench".into(),
                    sets: vec![ExerciseSet::Reps {
                        reps: 8,
                        weight: 60.0,
                    }],
                }],
            }
        );

        let distance = apply_update(
            date,
            &strength,
            &SessionUpdate {
                distance_km: Some(10.0),
                ..Default::default()
            },
        )
        .unwrap_err();
        assert_eq!(distance, STRENGTH_DISTANCE);

        let lifts = apply_update(
            date,
            &steady(10_000, 3_420),
            &SessionUpdate {
                exercises: Some(vec![ExerciseInput {
                    name: "squat".into(),
                    sets: vec![],
                }]),
                ..Default::default()
            },
        )
        .unwrap_err();
        assert_eq!(lifts, DISTANCE_EXERCISES);
    }

    #[test]
    fn the_schema_speaks_kilometres_and_minutes() {
        let schema = schemars::schema_for!(DistanceSession);
        let text = serde_json::to_string(&schema).unwrap();
        assert!(text.contains("distance_km"), "{text}");
        assert!(text.contains("minutes"), "{text}");
        assert!(text.contains("on_date"), "{text}");

        let strength = schemars::schema_for!(StrengthSession);
        let text = serde_json::to_string(&strength).unwrap();
        assert!(text.contains("weight_kg"), "{text}");
        assert!(text.contains("hold_seconds"), "{text}");
    }
}
