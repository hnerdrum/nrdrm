use std::io::Write;

use diesel::deserialize::{self, FromSql, FromSqlRow};
use diesel::expression::AsExpression;
use diesel::pg::{Pg, PgValue};
use diesel::serialize::{self, IsNull, Output, ToSql};
use serde::{Deserialize, Serialize};

use crate::database::schema::sql_types;

/// Where an imported session came from. A manual session has no source.
/// The provider and activity id together are unique.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActivitySource {
    pub provider: ActivityProvider,
    pub activity_id: String,
}

#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash, AsExpression, FromSqlRow, Serialize, Deserialize,
)]
#[diesel(sql_type = sql_types::ActivityProvider)]
#[serde(rename_all = "lowercase")]
pub enum ActivityProvider {
    Garmin,
}

impl ActivityProvider {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Garmin => "garmin",
        }
    }
}

impl ToSql<sql_types::ActivityProvider, Pg> for ActivityProvider {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        out.write_all(self.as_str().as_bytes())?;
        Ok(IsNull::No)
    }
}

impl FromSql<sql_types::ActivityProvider, Pg> for ActivityProvider {
    fn from_sql(value: PgValue<'_>) -> deserialize::Result<Self> {
        match value.as_bytes() {
            b"garmin" => Ok(Self::Garmin),
            other => Err(format!(
                "unrecognized activity provider: {}",
                String::from_utf8_lossy(other)
            )
            .into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn garmin_is_the_provider_name() {
        assert_eq!(ActivityProvider::Garmin.as_str(), "garmin");
        let json = serde_json::to_value(ActivityProvider::Garmin).unwrap();
        assert_eq!(json, serde_json::json!("garmin"));
        let parsed: ActivityProvider = serde_json::from_value(json).unwrap();
        assert_eq!(parsed, ActivityProvider::Garmin);
    }
}
