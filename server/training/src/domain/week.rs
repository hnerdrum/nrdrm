use chrono::{Datelike, Duration, NaiveDate, Weekday};

use super::session::{Session, SessionBody};

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct WeekTotals {
    pub run_seconds: u32,
    pub ride_seconds: u32,
    pub ski_seconds: u32,
    pub ski_metres: u32,
    pub strength_sessions: u32,
}

pub fn week_totals(sessions: &[Session], monday: NaiveDate) -> WeekTotals {
    debug_assert_eq!(monday.weekday(), Weekday::Mon);
    let end = monday + Duration::days(7);
    let mut totals = WeekTotals::default();
    for session in sessions {
        if session.on_date < monday || session.on_date >= end {
            continue;
        }
        match session.body {
            SessionBody::Ski {
                distance, duration, ..
            } => {
                totals.ski_seconds += duration;
                totals.ski_metres += distance;
            }
            SessionBody::Run { duration, .. } => totals.run_seconds += duration,
            SessionBody::Ride { duration, .. } => totals.ride_seconds += duration,
            SessionBody::Strength { .. } => totals.strength_sessions += 1,
        }
    }
    totals
}

#[cfg(test)]
mod tests {
    use chrono::NaiveDate;

    use super::*;
    use crate::domain::session::{Exercise, ExerciseSet, SessionBody};

    fn date(year: i32, month: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(year, month, day).unwrap()
    }

    fn session(day: u32, body: SessionBody) -> Session {
        Session {
            on_date: date(2026, 11, day),
            body,
        }
    }

    #[test]
    fn ski_distance_and_time_are_summed() {
        let monday = date(2026, 11, 2);
        let sessions = [
            session(
                2,
                SessionBody::Ski {
                    distance: 4_000,
                    duration: 1_800,
                    intervals: vec![],
                },
            ),
            session(
                8,
                SessionBody::Ski {
                    distance: 10_000,
                    duration: 3_600,
                    intervals: vec![],
                },
            ),
        ];

        assert_eq!(
            week_totals(&sessions, monday),
            WeekTotals {
                run_seconds: 0,
                ride_seconds: 0,
                ski_seconds: 5_400,
                ski_metres: 14_000,
                strength_sessions: 0,
            }
        );
    }

    #[test]
    fn strength_session_counts_and_adds_no_distance() {
        let monday = date(2026, 11, 2);
        let sessions = [session(
            4,
            SessionBody::Strength {
                exercises: vec![Exercise {
                    name: "squat".into(),
                    sets: vec![ExerciseSet::Reps {
                        reps: 5,
                        weight: 100.0,
                    }],
                }],
            },
        )];

        assert_eq!(
            week_totals(&sessions, monday),
            WeekTotals {
                run_seconds: 0,
                ride_seconds: 0,
                ski_seconds: 0,
                ski_metres: 0,
                strength_sessions: 1,
            }
        );
    }

    #[test]
    fn an_empty_week_is_all_zeros() {
        let monday = date(2026, 11, 2);
        let sessions = [
            session(
                1,
                SessionBody::Ski {
                    distance: 8_000,
                    duration: 2_400,
                    intervals: vec![],
                },
            ),
            session(9, SessionBody::Strength { exercises: vec![] }),
        ];

        assert_eq!(week_totals(&sessions, monday), WeekTotals::default());
        assert_eq!(week_totals(&[], monday), WeekTotals::default());
    }

    #[test]
    fn sums_time_for_each_sport() {
        let monday = date(2026, 11, 2);
        let sessions = [
            session(
                3,
                SessionBody::Run {
                    distance: 5_000,
                    duration: 1_500,
                    intervals: vec![],
                },
            ),
            session(
                3,
                SessionBody::Run {
                    distance: 1_000,
                    duration: 300,
                    intervals: vec![],
                },
            ),
            session(
                5,
                SessionBody::Ride {
                    distance: 40_000,
                    duration: 3_600,
                    intervals: vec![],
                },
            ),
        ];

        assert_eq!(
            week_totals(&sessions, monday),
            WeekTotals {
                run_seconds: 1_800,
                ride_seconds: 3_600,
                ski_seconds: 0,
                ski_metres: 0,
                strength_sessions: 0,
            }
        );
    }
}
