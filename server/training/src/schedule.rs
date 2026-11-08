use std::future::Future;

use chrono::{DateTime, Datelike, Duration, NaiveDate, TimeZone};
use chrono_tz::Europe::Oslo;
use chrono_tz::Tz;
use tracing::{error, info};

use crate::router::main::AppState;
use crate::router::sync::{run_sync, SyncError, SyncResponse};

/// The next 02:00 Europe/Oslo strictly after `now`.
/// On the spring-forward night, when 02:00 does not exist, the run is at 03:00.
/// On the fall-back night, when 02:00 happens twice, the earlier one is used.
pub fn next_night(now: DateTime<Tz>) -> DateTime<Tz> {
    let today = now.date_naive();
    for day in 0..7 {
        let date = today + Duration::days(day);
        if let Some(at) = at_two(date) {
            if at > now {
                return at;
            }
        }
    }
    now + Duration::hours(24)
}

fn at_two(date: NaiveDate) -> Option<DateTime<Tz>> {
    Oslo.with_ymd_and_hms(date.year(), date.month(), date.day(), 2, 0, 0)
        .earliest()
        .or_else(|| {
            Oslo.with_ymd_and_hms(date.year(), date.month(), date.day(), 3, 0, 0)
                .earliest()
        })
}

/// Waits until the next 02:00, then runs the same import as `POST /api/sync`.
pub(crate) async fn wait_and_sync<F, Fut>(
    state: &AppState,
    sleep_until: F,
) -> Result<SyncResponse, SyncError>
where
    F: FnOnce(DateTime<Tz>) -> Fut,
    Fut: Future<Output = ()>,
{
    let next = next_night(state.clock.now());
    sleep_until(next).await;
    run_sync(state).await
}

pub async fn nightly(state: AppState) {
    loop {
        match wait_and_sync(&state, sleep_until).await {
            Ok(result) => info!(
                "night sync stored {} sessions, skipped {}",
                result.sessions.len(),
                result.skipped.len()
            ),
            Err(err) => error!("night sync failed: {err}"),
        }
    }
}

async fn sleep_until(deadline: DateTime<Tz>) {
    let remaining = deadline.signed_duration_since(chrono::Utc::now().with_timezone(&Oslo));
    if let Ok(wait) = remaining.to_std() {
        if !wait.is_zero() {
            tokio::time::sleep(wait).await;
        }
    }
}

#[cfg(test)]
mod tests {
    use chrono::TimeZone;
    use chrono_tz::Europe::Oslo;
    use chrono_tz::Tz;

    use super::*;

    fn at(year: i32, month: u32, day: u32, hour: u32, minute: u32) -> DateTime<Tz> {
        Oslo.with_ymd_and_hms(year, month, day, hour, minute, 0)
            .single()
            .unwrap_or_else(|| {
                panic!("{year}-{month:02}-{day:02} {hour:02}:{minute:02} is not a single Oslo time")
            })
    }

    #[test]
    fn before_two_waits_until_this_morning() {
        let now = at(2026, 11, 8, 1, 15);
        assert_eq!(next_night(now), at(2026, 11, 8, 2, 0));
    }

    #[test]
    fn at_two_waits_until_the_next_morning() {
        let now = at(2026, 11, 8, 2, 0);
        assert_eq!(next_night(now), at(2026, 11, 9, 2, 0));
    }

    #[test]
    fn after_two_waits_until_the_next_morning() {
        let now = at(2026, 11, 8, 22, 0);
        assert_eq!(next_night(now), at(2026, 11, 9, 2, 0));
    }

    #[test]
    fn the_spring_forward_night_runs_at_three() {
        let now = at(2026, 3, 29, 1, 30);
        assert_eq!(next_night(now), at(2026, 3, 29, 3, 0));
    }

    #[test]
    fn the_fall_back_night_uses_the_earlier_two() {
        let now = at(2026, 10, 25, 1, 30);
        let earlier = Oslo
            .with_ymd_and_hms(2026, 10, 25, 2, 0, 0)
            .earliest()
            .expect("earlier 02:00");
        assert_eq!(next_night(now), earlier);
    }

    #[test]
    fn during_the_repeated_hour_the_next_run_is_tomorrow() {
        let later = Oslo
            .with_ymd_and_hms(2026, 10, 25, 2, 30, 0)
            .latest()
            .expect("later 02:30");
        assert_eq!(next_night(later), at(2026, 10, 26, 2, 0));
    }
}
