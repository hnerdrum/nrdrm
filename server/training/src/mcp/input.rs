use chrono::NaiveDate;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// A run, ride, or ski as an agent types it.
///
/// `distance_km` and `minutes` can be omitted when `intervals` is present.
/// The repeats are then totalled into the stored metres and seconds.
/// `on_date` defaults to today in Europe/Oslo.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct DistanceSession {
    #[serde(default)]
    pub on_date: Option<NaiveDate>,
    #[serde(default)]
    pub distance_km: Option<f64>,
    #[serde(default)]
    pub minutes: Option<f64>,
    #[serde(default)]
    pub intervals: Vec<IntervalInput>,
}

/// One block of repeats in a run, ride, or ski.
///
/// `distance_m` is the metres of one repeat and `seconds` is its time.
/// A repeat needs one of them. `recovery_seconds` is the rest between
/// repeats, and it counts toward the session time when the repeat has a time.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct IntervalInput {
    pub repetitions: u32,
    #[serde(default)]
    pub distance_m: u32,
    #[serde(default)]
    pub seconds: u32,
    #[serde(default)]
    pub recovery_seconds: u32,
}

/// A strength session as an agent types it.
/// `on_date` defaults to today in Europe/Oslo.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct StrengthSession {
    #[serde(default)]
    pub on_date: Option<NaiveDate>,
    pub exercises: Vec<ExerciseInput>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct ExerciseInput {
    pub name: String,
    pub sets: Vec<SetInput>,
}

/// A loaded or bodyweight effort, or a timed hold such as a plank.
///
/// A rep set has `reps` and an optional `weight_kg`. Bodyweight omits the
/// weight. A hold has `hold_seconds` and no reps.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct SetInput {
    #[serde(default)]
    pub reps: Option<u32>,
    #[serde(default)]
    pub weight_kg: Option<f64>,
    #[serde(default)]
    pub hold_seconds: Option<u32>,
}

/// Changes to one stored session. A field that is omitted stays as it is.
///
/// The sport stays too. A run does not become a strength session.
/// `intervals` or `exercises`, when present, replace that list. An empty
/// interval list removes the repeats and leaves the distance and time.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct SessionUpdate {
    #[serde(default)]
    pub on_date: Option<NaiveDate>,
    #[serde(default)]
    pub distance_km: Option<f64>,
    #[serde(default)]
    pub minutes: Option<f64>,
    #[serde(default)]
    pub intervals: Option<Vec<IntervalInput>>,
    #[serde(default)]
    pub exercises: Option<Vec<ExerciseInput>>,
}

/// A date inside the week to read. Omitted means today in Europe/Oslo.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct WeekQuery {
    #[serde(default)]
    pub on_date: Option<NaiveDate>,
}

/// `run`, `ride`, `ski`, or `strength`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(rename_all = "lowercase")]
pub enum SportName {
    #[default]
    Run,
    Ride,
    Ski,
    Strength,
}

/// The newest session of one sport. `through` omitted means today in Europe/Oslo.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct LatestQuery {
    pub sport: SportName,
    #[serde(default)]
    pub through: Option<NaiveDate>,
}

/// One stored session and the fields to change. Omitted fields stay as they are.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct UpdateQuery {
    pub id: Uuid,
    #[serde(default)]
    pub on_date: Option<NaiveDate>,
    #[serde(default)]
    pub distance_km: Option<f64>,
    #[serde(default)]
    pub minutes: Option<f64>,
    #[serde(default)]
    pub intervals: Option<Vec<IntervalInput>>,
    #[serde(default)]
    pub exercises: Option<Vec<ExerciseInput>>,
}

impl UpdateQuery {
    pub(crate) fn change(&self) -> SessionUpdate {
        SessionUpdate {
            on_date: self.on_date,
            distance_km: self.distance_km,
            minutes: self.minutes,
            intervals: self.intervals.clone(),
            exercises: self.exercises.clone(),
        }
    }
}

/// The session to delete.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct DeleteQuery {
    pub id: Uuid,
}
