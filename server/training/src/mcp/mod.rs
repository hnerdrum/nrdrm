//! The units an agent types, and the session they become.
//!
//! Distance is kilometres and time is minutes. A stored session is metres
//! and seconds. Pace and speed are derived, the same way the page derives them.
//! The agent calls these through `/api/mcp`.

mod convert;
pub(crate) mod http;
mod input;
mod render;
mod tools;

pub use convert::{
    apply_update, prepare_ride, prepare_run, prepare_ski, prepare_strength, PreparedSession,
};
pub use input::{
    DistanceSession, ExerciseInput, IntervalInput, SessionUpdate, SetInput, StrengthSession,
};
pub use render::{render, render_preset, RenderedPreset, RenderedSession, RenderedSource};
