use chrono::{NaiveDate, Utc};
use chrono_tz::Europe::Oslo;

pub trait Clock: Send + Sync {
    fn today(&self) -> NaiveDate;
}

#[derive(Clone, Copy)]
pub struct OsloClock;

impl Clock for OsloClock {
    fn today(&self) -> NaiveDate {
        Utc::now().with_timezone(&Oslo).date_naive()
    }
}

#[cfg(test)]
#[derive(Clone, Copy)]
pub struct FixedClock(pub NaiveDate);

#[cfg(test)]
impl Clock for FixedClock {
    fn today(&self) -> NaiveDate {
        self.0
    }
}
