use async_trait::async_trait;
use chrono::NaiveDate;

use crate::domain::import::ActivitySummary;

#[derive(Debug)]
pub struct ActivityClientError;

impl std::fmt::Display for ActivityClientError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("activity provider did not respond")
    }
}

impl std::error::Error for ActivityClientError {}

#[async_trait]
pub trait ActivityClient: Send + Sync {
    async fn summaries(
        &self,
        from: NaiveDate,
        to: NaiveDate,
    ) -> Result<Vec<ActivitySummary>, ActivityClientError>;
}
