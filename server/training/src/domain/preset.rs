//! A preset is a named session body with no date, kept to start new sessions
//! from. Logging a session from a preset copies the body; later changes to
//! the preset leave logged sessions alone.

use super::session::SessionBody;

/// The longest name a preset may have, in characters.
pub const NAME_LIMIT: usize = 60;

const NAME: &str = "Name the preset";
const NAME_TOO_LONG: &str = "A preset name is at most 60 characters";
const STEADY: &str = "A preset needs a distance and a time";
const EXERCISES: &str = "Name each exercise and give it a set";

/// The name as it is stored: trimmed, and not blank or too long.
pub fn preset_name(raw: &str) -> Result<String, &'static str> {
    let name = raw.trim();
    if name.is_empty() {
        return Err(NAME);
    }
    if name.chars().count() > NAME_LIMIT {
        return Err(NAME_TOO_LONG);
    }
    Ok(name.to_string())
}

/// Why a body can't be a preset, if it can't.
///
/// A preset fills the New session form, so it has to be a body that form
/// would save: everything a session needs, plus a distance and a time on a
/// steady session and at least one named exercise with a set.
pub fn body_rejection(body: &SessionBody) -> Option<&'static str> {
    if let Some(message) = body.rejection() {
        return Some(message);
    }
    match body {
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
        } if intervals.is_empty() && (*distance == 0 || *duration == 0) => Some(STEADY),
        SessionBody::Strength { exercises }
            if exercises.is_empty()
                || exercises.iter().any(|exercise| {
                    exercise.name.trim().is_empty() || exercise.sets.is_empty()
                }) =>
        {
            Some(EXERCISES)
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session::{Exercise, ExerciseSet, Interval};

    fn strength(name: &str, sets: Vec<ExerciseSet>) -> SessionBody {
        SessionBody::Strength {
            exercises: vec![Exercise {
                name: name.into(),
                sets,
            }],
        }
    }

    #[test]
    fn a_name_is_trimmed() {
        assert_eq!(preset_name("  Leg day "), Ok("Leg day".to_string()));
    }

    #[test]
    fn a_blank_name_is_rejected() {
        assert_eq!(preset_name(""), Err(NAME));
        assert_eq!(preset_name(" \t "), Err(NAME));
    }

    #[test]
    fn a_name_is_at_most_sixty_characters() {
        let longest = "å".repeat(NAME_LIMIT);
        assert_eq!(preset_name(&longest), Ok(longest.clone()));
        assert_eq!(preset_name(&format!("{longest}x")), Err(NAME_TOO_LONG));
    }

    #[test]
    fn a_body_a_session_rejects_is_rejected() {
        let short = SessionBody::Run {
            distance: 1_000,
            duration: 220,
            intervals: vec![Interval {
                repetitions: 4,
                distance: 1_000,
                duration: 220,
                recovery: 90,
            }],
        };
        assert_eq!(
            body_rejection(&short),
            Some("Each interval needs repeats, and a distance or a time")
        );
        assert_eq!(
            body_rejection(&strength(
                "squat",
                vec![ExerciseSet::Reps {
                    reps: 0,
                    weight: 0.0
                }]
            )),
            Some("Each set needs reps or a duration")
        );
    }

    #[test]
    fn a_steady_preset_needs_a_distance_and_a_time() {
        for (distance, duration) in [(0, 1_800), (5_000, 0), (0, 0)] {
            let run = SessionBody::Run {
                distance,
                duration,
                intervals: vec![],
            };
            assert_eq!(body_rejection(&run), Some(STEADY), "{distance} {duration}");
        }
        let steady = SessionBody::Ride {
            distance: 40_000,
            duration: 3_600,
            intervals: vec![],
        };
        assert_eq!(body_rejection(&steady), None);
    }

    #[test]
    fn an_interval_preset_may_be_timed_only() {
        let timed = SessionBody::Ski {
            distance: 0,
            duration: 480,
            intervals: vec![Interval {
                repetitions: 8,
                distance: 0,
                duration: 60,
                recovery: 0,
            }],
        };
        assert_eq!(body_rejection(&timed), None);
    }

    #[test]
    fn a_strength_preset_needs_named_exercises_with_sets() {
        assert_eq!(
            body_rejection(&SessionBody::Strength { exercises: vec![] }),
            Some(EXERCISES)
        );
        assert_eq!(
            body_rejection(&strength(" ", vec![ExerciseSet::Hold { duration: 45 }])),
            Some(EXERCISES)
        );
        assert_eq!(body_rejection(&strength("squat", vec![])), Some(EXERCISES));
        assert_eq!(
            body_rejection(&strength(
                "squat",
                vec![ExerciseSet::Reps {
                    reps: 5,
                    weight: 100.0
                }]
            )),
            None
        );
    }
}
