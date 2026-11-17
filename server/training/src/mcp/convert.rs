use chrono::NaiveDate;

use crate::clock::Clock;
use crate::domain::session::{
    block_totals, Block, Exercise, ExerciseSet, Interval, SessionBody, Sport, Steady,
};

use super::input::{BlockInput, DistanceSession, SessionUpdate, SetInput, StrengthSession};

const SET: &str = "Each set needs reps or a duration";
const TOO_LONG: &str = "That session is too long to store";
const STRENGTH_DISTANCE: &str = "A strength session has no distance or time";

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
        body: strength_body(blocks(&input.blocks)?)?,
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

/// A body with no date, from the fields the log tools take, in the same
/// units and with the same totals as `prepare_run` and `prepare_strength`.
pub fn body_from_input(
    sport: Sport,
    distance_km: Option<f64>,
    minutes: Option<f64>,
    input: &[BlockInput],
) -> Result<SessionBody, &'static str> {
    if sport == Sport::Strength {
        if distance_km.is_some() || minutes.is_some() {
            return Err(STRENGTH_DISTANCE);
        }
        return strength_body(blocks(input)?);
    }
    distance_from_input(
        sport,
        &DistanceSession {
            on_date: None,
            distance_km,
            minutes,
            blocks: input.to_vec(),
        },
    )
}

/// `body` with the fields in `update` changed, by the rules `update_session`
/// follows. The update's date, if any, is not part of a body.
pub fn update_body(
    body: &SessionBody,
    update: &SessionUpdate,
) -> Result<SessionBody, &'static str> {
    merge_body(body, update)
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
    let blocks = blocks(&input.blocks)?;
    let (distance, duration) = if blocks.is_empty() {
        (
            metres(input.distance_km.ok_or(needs_distance(sport))?)?,
            seconds(input.minutes.ok_or(needs_time(sport))?)?,
        )
    } else {
        // A distance or a time left out is what the blocks add up to. One
        // sent alongside them may be more, but not less, which is the check
        // `rejection` already makes.
        let (total_distance, total_duration) = block_totals(&blocks).ok_or(TOO_LONG)?;
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
    accept(sport, distance, duration, blocks)
}

fn merge_body(body: &SessionBody, update: &SessionUpdate) -> Result<SessionBody, &'static str> {
    let Some((distance, duration)) = body.totals() else {
        if update.distance_km.is_some() || update.minutes.is_some() {
            return Err(STRENGTH_DISTANCE);
        }
        return match &update.blocks {
            Some(list) => strength_body(blocks(list)?),
            None => Ok(body.clone()),
        };
    };

    let (blocks, fallback_distance, fallback_duration) = match &update.blocks {
        None => (body.blocks().to_vec(), distance, duration),
        Some(list) => {
            // A total that was only what the old blocks added up to follows
            // the new ones. One that was more, such as the watch's, stays.
            let blocks = blocks(list)?;
            let (old_distance, old_duration) = block_totals(body.blocks()).ok_or(TOO_LONG)?;
            let (new_distance, new_duration) = block_totals(&blocks).ok_or(TOO_LONG)?;
            let derived = !body.blocks().is_empty() && !blocks.is_empty();
            (
                blocks,
                if derived && distance == old_distance {
                    new_distance
                } else {
                    distance
                },
                if derived && duration == old_duration {
                    new_duration
                } else {
                    duration
                },
            )
        }
    };
    accept(
        body.sport(),
        match update.distance_km {
            Some(kilometres) => metres(kilometres)?,
            None => fallback_distance,
        },
        match update.minutes {
            Some(minutes) => seconds(minutes)?,
            None => fallback_duration,
        },
        blocks,
    )
}

fn accept(
    sport: Sport,
    distance: u32,
    duration: u32,
    blocks: Vec<Block>,
) -> Result<SessionBody, &'static str> {
    let body = match sport {
        Sport::Run => SessionBody::Run {
            distance,
            duration,
            blocks,
        },
        Sport::Ride => SessionBody::Ride {
            distance,
            duration,
            blocks,
        },
        Sport::Ski => SessionBody::Ski {
            distance,
            duration,
            blocks,
        },
        Sport::Strength => return Err(STRENGTH_DISTANCE),
    };
    match body.rejection() {
        Some(message) => Err(message),
        None => Ok(body),
    }
}

fn strength_body(blocks: Vec<Block>) -> Result<SessionBody, &'static str> {
    let body = SessionBody::Strength { blocks };
    match body.rejection() {
        Some(message) => Err(message),
        None => Ok(body),
    }
}

fn blocks(input: &[BlockInput]) -> Result<Vec<Block>, &'static str> {
    input.iter().map(block).collect()
}

fn block(input: &BlockInput) -> Result<Block, &'static str> {
    Ok(match input {
        BlockInput::Steady {
            name,
            distance_km,
            minutes,
        } => Block::Steady(Steady {
            distance: distance_km.map(metres).transpose()?.unwrap_or(0),
            duration: minutes.map(seconds).transpose()?.unwrap_or(0),
            name: name.as_deref().map(|name| name.trim().to_string()),
        }),
        BlockInput::Repeats {
            repetitions,
            distance_m,
            seconds,
            recovery_seconds,
        } => Block::Repeats(Interval {
            repetitions: *repetitions,
            distance: *distance_m,
            duration: *seconds,
            recovery: *recovery_seconds,
        }),
        BlockInput::Exercise { name, sets } => Block::Exercise(Exercise {
            name: name.trim().to_string(),
            sets: sets.iter().map(set).collect::<Result<Vec<_>, _>>()?,
        }),
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

    const OVER: &str = "The blocks add up to more than the session";

    fn date(year: i32, month: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(year, month, day).unwrap()
    }

    fn clock() -> FixedClock {
        FixedClock(date(2026, 11, 8))
    }

    fn run(distance: u32, duration: u32, blocks: Vec<Block>) -> SessionBody {
        SessionBody::Run {
            distance,
            duration,
            blocks,
        }
    }

    fn steady(distance: u32, duration: u32) -> SessionBody {
        run(distance, duration, vec![])
    }

    fn repeats_in(repetitions: u32, distance_m: u32, seconds: u32, recovery: u32) -> BlockInput {
        BlockInput::Repeats {
            repetitions,
            distance_m,
            seconds,
            recovery_seconds: recovery,
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

    fn steady_in(name: Option<&str>, distance_km: Option<f64>, minutes: Option<f64>) -> BlockInput {
        BlockInput::Steady {
            name: name.map(str::to_string),
            distance_km,
            minutes,
        }
    }

    fn steady_block(name: Option<&str>, distance: u32, duration: u32) -> Block {
        Block::Steady(Steady {
            distance,
            duration,
            name: name.map(str::to_string),
        })
    }

    fn squat_in(weight_kg: f64) -> BlockInput {
        BlockInput::Exercise {
            name: "squat".into(),
            sets: vec![SetInput {
                reps: Some(5),
                weight_kg: Some(weight_kg),
                hold_seconds: None,
            }],
        }
    }

    fn squat(weight: f64) -> Block {
        Block::Exercise(Exercise {
            name: "squat".into(),
            sets: vec![ExerciseSet::Reps { reps: 5, weight }],
        })
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

        assert_eq!(
            prepare_ride(&input, &clock()).unwrap().body,
            SessionBody::Ride {
                distance: 10_000,
                duration: 3_420,
                blocks: vec![],
            }
        );
        assert_eq!(
            prepare_ski(&input, &clock()).unwrap().body,
            SessionBody::Ski {
                distance: 10_000,
                duration: 3_420,
                blocks: vec![],
            }
        );

        for extra in [
            r#"{"distance_km":10,"minutes":57,"sport":"run"}"#,
            r#"{"distance_km":10,"minutes":57,"intervals":[]}"#,
        ] {
            assert!(
                serde_json::from_str::<DistanceSession>(extra).is_err(),
                "{extra}"
            );
        }
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
    fn blocks_parse_by_kind() {
        let input: DistanceSession = serde_json::from_str(
            r#"{"blocks":[{"kind":"steady","name":"warmup","minutes":15},{"kind":"repeats","repetitions":5,"distance_m":1000,"seconds":210,"recovery_seconds":90},{"kind":"steady","name":"cooldown","distance_km":2,"minutes":10}]}"#,
        )
        .unwrap();
        assert_eq!(
            input.blocks,
            vec![
                steady_in(Some("warmup"), None, Some(15.0)),
                repeats_in(5, 1000, 210, 90),
                steady_in(Some("cooldown"), Some(2.0), Some(10.0)),
            ]
        );
        for wrong in [
            r#"{"blocks":[{"kind":"lap","minutes":15}]}"#,
            r#"{"blocks":[{"minutes":15}]}"#,
            r#"{"blocks":[{"kind":"steady","minutes":15,"pace":"easy"}]}"#,
            r#"{"blocks":[{"kind":"repeats","repetitions":5,"distance":1000}]}"#,
        ] {
            assert!(
                serde_json::from_str::<DistanceSession>(wrong).is_err(),
                "{wrong}"
            );
        }
    }

    #[test]
    fn repeats_are_totalled_into_the_stored_distance_and_time() {
        // 4 × 1000m in 3:40, 90s between, then 4 × 400m in 80s, 60s between.
        // 4*1000 + 4*400 = 5600m. Work 4*220 + 4*80, rests 3*90 + 3*60 = 1650s.
        let input = DistanceSession {
            blocks: vec![repeats_in(4, 1000, 220, 90), repeats_in(4, 400, 80, 60)],
            ..Default::default()
        };
        assert_eq!(
            prepare_run(&input, &clock()).unwrap().body,
            run(
                5_600,
                1_650,
                vec![repeats(4, 1000, 220, 90), repeats(4, 400, 80, 60)]
            )
        );

        let short = DistanceSession {
            distance_km: Some(1.0),
            ..input
        };
        assert_eq!(prepare_run(&short, &clock()).unwrap_err(), OVER);
    }

    #[test]
    fn a_warmup_and_cooldown_add_to_the_totals_or_fit_inside_them() {
        let blocks = vec![
            steady_in(Some(" warmup "), None, Some(15.0)),
            repeats_in(5, 1000, 210, 90),
            steady_in(Some("cooldown"), Some(2.0), Some(10.0)),
        ];
        let stored = vec![
            steady_block(Some("warmup"), 0, 900),
            repeats(5, 1000, 210, 90),
            steady_block(Some("cooldown"), 2_000, 600),
        ];

        // 5000 + 2000 m; 900 + 5*210 + 4*90 + 600 = 2910 s.
        let summed = prepare_run(
            &DistanceSession {
                blocks: blocks.clone(),
                ..Default::default()
            },
            &clock(),
        )
        .unwrap();
        assert_eq!(summed.body, run(7_000, 2_910, stored.clone()));

        let watch = prepare_run(
            &DistanceSession {
                distance_km: Some(11.2),
                minutes: Some(55.0),
                blocks: blocks.clone(),
                ..Default::default()
            },
            &clock(),
        )
        .unwrap();
        assert_eq!(watch.body, run(11_200, 3_300, stored));

        let too_short = DistanceSession {
            minutes: Some(48.0),
            blocks,
            ..Default::default()
        };
        assert_eq!(prepare_run(&too_short, &clock()).unwrap_err(), OVER);
    }

    #[test]
    fn a_block_has_to_suit_the_sport_and_be_whole() {
        assert_eq!(
            prepare_run(
                &DistanceSession {
                    blocks: vec![squat_in(100.0)],
                    ..Default::default()
                },
                &clock(),
            )
            .unwrap_err(),
            "Exercises belong on a strength session"
        );
        assert_eq!(
            prepare_strength(
                &StrengthSession {
                    blocks: vec![repeats_in(4, 400, 90, 60)],
                    ..Default::default()
                },
                &clock(),
            )
            .unwrap_err(),
            "Repeats belong on a run, ride or ski"
        );
        assert_eq!(
            prepare_run(
                &DistanceSession {
                    blocks: vec![repeats_in(0, 400, 90, 0)],
                    ..Default::default()
                },
                &clock(),
            )
            .unwrap_err(),
            "Each interval needs repeats, and a distance or a time"
        );
        assert_eq!(
            prepare_run(
                &DistanceSession {
                    blocks: vec![steady_in(Some("warmup"), None, None)],
                    distance_km: Some(5.0),
                    minutes: Some(25.0),
                    ..Default::default()
                },
                &clock(),
            )
            .unwrap_err(),
            "Each steady block needs a distance or a time"
        );
        assert_eq!(
            prepare_run(
                &DistanceSession {
                    blocks: vec![steady_in(None, None, Some(-1.0))],
                    ..Default::default()
                },
                &clock(),
            )
            .unwrap_err(),
            "A time needs to be a number of minutes"
        );
    }

    #[test]
    fn a_strength_session_stores_a_warmup_reps_weight_and_holds() {
        let input: StrengthSession = serde_json::from_str(
            r#"{"blocks":[{"kind":"steady","name":"row","minutes":10},{"kind":"exercise","name":"squat","sets":[{"reps":5,"weight_kg":100}]},{"kind":"exercise","name":"plank","sets":[{"hold_seconds":45}]},{"kind":"exercise","name":"pull-up","sets":[{"reps":8}]}]}"#,
        )
        .unwrap();
        let prepared = prepare_strength(&input, &clock()).unwrap();
        assert_eq!(prepared.on_date, date(2026, 11, 8));
        assert_eq!(
            prepared.body,
            SessionBody::Strength {
                blocks: vec![
                    steady_block(Some("row"), 0, 600),
                    squat(100.0),
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
            }
        );
        assert!(serde_json::from_str::<StrengthSession>(r#"{"exercises":[]}"#).is_err());
    }

    #[test]
    fn a_bad_set_returns_the_domain_message() {
        for sets in [
            vec![SetInput {
                reps: Some(0),
                ..Default::default()
            }],
            vec![SetInput {
                reps: Some(5),
                hold_seconds: Some(45),
                ..Default::default()
            }],
        ] {
            let input = StrengthSession {
                blocks: vec![BlockInput::Exercise {
                    name: "plank".into(),
                    sets,
                }],
                ..Default::default()
            };
            assert_eq!(
                prepare_strength(&input, &clock()).unwrap_err(),
                "Each set needs reps or a duration"
            );
        }
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
    fn an_interval_session_may_be_longer_than_its_repeats() {
        // The repeats are 4000 m in 4*220 + 3*90 = 1150 s.
        let stored = run(4_000, 1_150, vec![repeats(4, 1000, 220, 90)]);
        let longer = apply_update(
            date(2026, 11, 8),
            &stored,
            &SessionUpdate {
                minutes: Some(20.0),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(longer.body, run(4_000, 1_200, stored.blocks().to_vec()));

        let err = apply_update(
            date(2026, 11, 8),
            &stored,
            &SessionUpdate {
                minutes: Some(19.0),
                ..Default::default()
            },
        )
        .unwrap_err();
        assert_eq!(err, OVER);

        let cleared = apply_update(
            date(2026, 11, 8),
            &stored,
            &SessionUpdate {
                blocks: Some(vec![]),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(cleared.body, steady(4_000, 1_150));
    }

    #[test]
    fn new_blocks_move_totals_that_were_their_sum_and_keep_the_watch_figures() {
        let six = run(6_000, 1_770, vec![repeats(6, 1000, 220, 90)]);
        let five = SessionUpdate {
            blocks: Some(vec![repeats_in(5, 1000, 220, 90)]),
            ..Default::default()
        };
        // 5000 m in 5*220 + 4*90 = 1460 s.
        assert_eq!(
            update_body(&six, &five).unwrap(),
            run(5_000, 1_460, vec![repeats(5, 1000, 220, 90)])
        );

        let watch = run(11_200, 3_300, vec![repeats(6, 1000, 220, 90)]);
        assert_eq!(
            update_body(&watch, &five).unwrap(),
            run(11_200, 3_300, vec![repeats(5, 1000, 220, 90)])
        );

        // Structure added to a steady session from the watch.
        let plain = steady(11_200, 3_300);
        let outlined = update_body(
            &plain,
            &SessionUpdate {
                blocks: Some(vec![
                    steady_in(Some("warmup"), None, Some(15.0)),
                    repeats_in(5, 1000, 210, 90),
                ]),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(outlined.totals(), Some((11_200, 3_300)));
        assert_eq!(outlined.blocks().len(), 2);

        // Blocks bigger than the session it keeps are an error, not a silent change.
        let small = steady(1_000, 300);
        assert_eq!(update_body(&small, &five).unwrap_err(), OVER);
    }

    #[test]
    fn the_sport_stays_the_same() {
        let date = date(2026, 11, 8);
        let strength = SessionBody::Strength {
            blocks: vec![squat(100.0)],
        };
        let updated = apply_update(
            date,
            &strength,
            &SessionUpdate {
                blocks: Some(vec![
                    steady_in(Some("row"), None, Some(10.0)),
                    squat_in(105.0),
                ]),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(
            updated.body,
            SessionBody::Strength {
                blocks: vec![steady_block(Some("row"), 0, 600), squat(105.0)],
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
                blocks: Some(vec![squat_in(100.0)]),
                ..Default::default()
            },
        )
        .unwrap_err();
        assert_eq!(lifts, "Exercises belong on a strength session");
    }

    #[test]
    fn the_schema_speaks_kilometres_and_minutes() {
        let schema = schemars::schema_for!(DistanceSession);
        let text = serde_json::to_string(&schema).unwrap();
        for field in [
            "distance_km",
            "minutes",
            "on_date",
            "blocks",
            "steady",
            "repeats",
            "recovery_seconds",
        ] {
            assert!(text.contains(field), "{field}: {text}");
        }

        let strength = schemars::schema_for!(StrengthSession);
        let text = serde_json::to_string(&strength).unwrap();
        assert!(text.contains("weight_kg"), "{text}");
        assert!(text.contains("hold_seconds"), "{text}");
    }

    #[test]
    fn a_body_without_a_date_uses_the_log_units() {
        assert_eq!(
            body_from_input(Sport::Ride, Some(40.0), Some(60.0), &[]).unwrap(),
            SessionBody::Ride {
                distance: 40_000,
                duration: 3_600,
                blocks: vec![],
            }
        );
        assert_eq!(
            body_from_input(Sport::Run, None, None, &[repeats_in(6, 1_000, 220, 90)]).unwrap(),
            run(6_000, 1_770, vec![repeats(6, 1_000, 220, 90)])
        );
        assert_eq!(
            body_from_input(Sport::Strength, None, None, &[squat_in(100.0)]).unwrap(),
            SessionBody::Strength {
                blocks: vec![squat(100.0)],
            }
        );
    }

    #[test]
    fn a_body_without_a_date_keeps_each_sport_to_its_fields() {
        assert_eq!(
            body_from_input(Sport::Strength, Some(5.0), None, &[]),
            Err(STRENGTH_DISTANCE)
        );
        assert_eq!(
            body_from_input(Sport::Ski, Some(10.0), Some(60.0), &[squat_in(100.0)]),
            Err("Exercises belong on a strength session")
        );
        assert_eq!(
            body_from_input(Sport::Run, None, Some(30.0), &[]),
            Err("A run needs a distance in kilometres")
        );
    }

    #[test]
    fn a_body_update_follows_the_session_rules() {
        let changed = update_body(
            &steady(10_000, 3_000),
            &SessionUpdate {
                minutes: Some(55.0),
                ..SessionUpdate::default()
            },
        )
        .unwrap();
        assert_eq!(changed, steady(10_000, 3_300));
    }
}
