use chrono::{DateTime, NaiveDate, Utc};
use chrono_tz::Europe::Oslo;
use chrono_tz::Tz;

#[cfg(test)]
use chrono::{Datelike, TimeZone};

pub trait Clock: Send + Sync {
    fn now(&self) -> DateTime<Tz>;

    fn today(&self) -> NaiveDate {
        self.now().date_naive()
    }
}

#[derive(Clone, Copy)]
pub struct OsloClock;

impl Clock for OsloClock {
    fn now(&self) -> DateTime<Tz> {
        Utc::now().with_timezone(&Oslo)
    }
}

#[cfg(test)]
#[derive(Clone, Copy)]
pub struct FixedClock(pub NaiveDate);

#[cfg(test)]
impl Clock for FixedClock {
    fn now(&self) -> DateTime<Tz> {
        Oslo.with_ymd_and_hms(self.0.year(), self.0.month(), self.0.day(), 12, 0, 0)
            .earliest()
            .expect("noon in Oslo")
    }
}
