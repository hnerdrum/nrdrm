//! The units an agent types, and the session they become.
//!
//! Distance is kilometres and time is minutes. A stored session is metres
//! and seconds. Pace and speed are derived, the same way the page derives them.

mod convert;
mod input;
mod render;

pub use convert::{
    apply_update, prepare_ride, prepare_run, prepare_ski, prepare_strength, PreparedSession,
};
pub use input::{
    DistanceSession, ExerciseInput, IntervalInput, SessionUpdate, SetInput, StrengthSession,
};
pub use render::{render, RenderedSession, RenderedSource};
