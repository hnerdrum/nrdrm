use chrono::NaiveDate;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// A run, ride, or ski as an agent types it.
///
/// `distance_km` and `minutes` are the whole session. `blocks` outline it in
/// order: steady stretches and repeats. With blocks, a distance or time left
/// out is what the blocks add up to; one given may be more, never less.
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
    pub blocks: Vec<BlockInput>,
}

/// One part of a session, in order, tagged by `kind`.
///
/// - `steady`: a stretch at one effort, such as a warmup, cooldown, easy or
///   tempo part, or ten minutes on the rower. `distance_km`, `minutes` or
///   both. Name a warmup exactly `warmup` and a cooldown exactly `cooldown`.
/// - `repeats`: `repetitions` of `distance_m` metres and/or `seconds`, with
///   `recovery_seconds` between them. The rest after the last repeat is not
///   part of the block. Run, ride and ski only.
/// - `exercise`: a named exercise and its sets. Strength only.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
pub enum BlockInput {
    Steady {
        #[serde(default, skip_serializing_if = "Option::is_none")]
        name: Option<String>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        distance_km: Option<f64>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        minutes: Option<f64>,
    },
    Repeats {
        repetitions: u32,
        #[serde(default)]
        distance_m: u32,
        #[serde(default)]
        seconds: u32,
        #[serde(default)]
        recovery_seconds: u32,
    },
    Exercise {
        name: String,
        sets: Vec<SetInput>,
    },
}

/// A strength session as an agent types it: exercise blocks, and steady
/// blocks for a warmup such as the rower. `on_date` defaults to today in
/// Europe/Oslo.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct StrengthSession {
    #[serde(default)]
    pub on_date: Option<NaiveDate>,
    pub blocks: Vec<BlockInput>,
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
/// `blocks`, when present, replace every block; `[]` removes them and leaves
/// the distance and time. An omitted distance or time stays, unless it was
/// what the old blocks added up to: then it follows the new blocks.
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
    pub blocks: Option<Vec<BlockInput>>,
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
    pub blocks: Option<Vec<BlockInput>>,
}

impl UpdateQuery {
    pub(crate) fn change(&self) -> SessionUpdate {
        SessionUpdate {
            on_date: self.on_date,
            distance_km: self.distance_km,
            minutes: self.minutes,
            blocks: self.blocks.clone(),
        }
    }
}

/// The session to delete.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct DeleteQuery {
    pub id: Uuid,
}

/// The presets to list: those of one sport, or every one when omitted.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct PresetsQuery {
    #[serde(default)]
    pub sport: Option<SportName>,
}

/// A new preset: a name and a session body with no date, in the units the
/// log tools take.
///
/// A strength preset has exercise blocks. A run, ride or ski has
/// `distance_km` and `minutes`, `blocks`, or both, as in the log tools.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct PresetInput {
    pub name: String,
    pub sport: SportName,
    #[serde(default)]
    pub distance_km: Option<f64>,
    #[serde(default)]
    pub minutes: Option<f64>,
    #[serde(default)]
    pub blocks: Vec<BlockInput>,
}

/// One preset and the fields to change. Omitted fields stay as they are, and
/// so does the sport. `blocks`, when present, replace every block, as in
/// `update_session`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct PresetUpdateQuery {
    pub id: Uuid,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub distance_km: Option<f64>,
    #[serde(default)]
    pub minutes: Option<f64>,
    #[serde(default)]
    pub blocks: Option<Vec<BlockInput>>,
}

impl PresetUpdateQuery {
    pub(crate) fn change(&self) -> SessionUpdate {
        SessionUpdate {
            on_date: None,
            distance_km: self.distance_km,
            minutes: self.minutes,
            blocks: self.blocks.clone(),
        }
    }
}

/// The preset to delete.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct PresetIdQuery {
    pub id: Uuid,
}

/// The preset to log, by `id` or by `name` (regardless of case), and the day.
/// Give one of `id` and `name`. `on_date` defaults to today in Europe/Oslo.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct LogPresetQuery {
    #[serde(default)]
    pub id: Option<Uuid>,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub on_date: Option<NaiveDate>,
}

/// A logged session to keep as a new preset, and the preset's name.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct SaveAsPresetQuery {
    pub session_id: Uuid,
    pub name: String,
}
