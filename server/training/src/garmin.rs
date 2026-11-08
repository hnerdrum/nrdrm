use std::collections::HashSet;

use async_trait::async_trait;
use base64::Engine;
use chrono::{DateTime, Duration, NaiveDate, NaiveDateTime, Utc};
use serde::Deserialize;
use tokio::sync::Mutex;
use tracing::{error, warn};

use crate::activities::{ActivityClient, ActivityClientError};
use crate::domain::import::{ActivityKind, ActivitySummary};
use crate::domain::source::{ActivityProvider, ActivitySource};

const ORIGIN: &str = "https://personal.connectapi.garmin.com";
const PAGE_LIMIT: i64 = 100;
const MAX_PAGES: i64 = 20;

#[derive(Clone)]
struct CachedToken {
    value: String,
    refresh_at: DateTime<Utc>,
}

struct ParsedPage {
    summaries: Vec<ActivitySummary>,
    len: usize,
}

pub struct GarminClient {
    http: reqwest::Client,
    api_key: String,
    token: Mutex<Option<CachedToken>>,
}

impl GarminClient {
    pub fn new(api_key: String) -> Self {
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .expect("garmin http client");
        Self {
            http,
            api_key,
            token: Mutex::new(None),
        }
    }

    async fn token(&self) -> Result<String, ActivityClientError> {
        if let Some(cached) = self.token.lock().await.as_ref() {
            if Utc::now() < cached.refresh_at {
                return Ok(cached.value.clone());
            }
        }
        let fresh = self.request_token().await?;
        *self.token.lock().await = Some(fresh.clone());
        Ok(fresh.value)
    }

    async fn clear_token(&self) {
        *self.token.lock().await = None;
    }

    async fn request_token(&self) -> Result<CachedToken, ActivityClientError> {
        let api_key = self.api_key.trim();
        if api_key.is_empty() {
            error!("GARMIN_API_KEY is not set");
            return Err(ActivityClientError);
        }
        let response = self
            .http
            .post(format!(
                "{ORIGIN}/personalapitoken-service/personal-api/personal-api-key/token"
            ))
            .header("Authorization", format!("ApiKey {api_key}"))
            .send()
            .await
            .map_err(|err| {
                error!("garmin token request failed: {err}");
                ActivityClientError
            })?;
        if !response.status().is_success() {
            error!("garmin token request returned {}", response.status());
            return Err(ActivityClientError);
        }
        let body = response.text().await.map_err(|err| {
            error!("garmin token response could not be read: {err}");
            ActivityClientError
        })?;
        let Some(value) = access_token(&body) else {
            error!("garmin token response was empty");
            return Err(ActivityClientError);
        };
        Ok(CachedToken {
            refresh_at: refresh_at(&value),
            value,
        })
    }

    async fn page_summaries(
        &self,
        from: NaiveDate,
        to: NaiveDate,
        start: i64,
    ) -> Result<ParsedPage, ActivityClientError> {
        let mut token = self.token().await?;
        // A 401 means the cached token is stale. Refresh once and retry the same page.
        for attempt in 0..2 {
            let response = self.request_page(&token, from, to, start).await?;
            if response.status() == reqwest::StatusCode::UNAUTHORIZED && attempt == 0 {
                self.clear_token().await;
                token = self.token().await?;
                continue;
            }
            if !response.status().is_success() {
                error!("garmin activities returned {}", response.status());
                return Err(ActivityClientError);
            }
            let body = response.text().await.map_err(|err| {
                error!("garmin activities could not be read: {err}");
                ActivityClientError
            })?;
            return parse_activity_summaries(&body);
        }
        Err(ActivityClientError)
    }

    async fn request_page(
        &self,
        token: &str,
        from: NaiveDate,
        to: NaiveDate,
        start: i64,
    ) -> Result<reqwest::Response, ActivityClientError> {
        self.http
            .get(format!(
                "{ORIGIN}/activitylist-service/activities/search/activities"
            ))
            .bearer_auth(token)
            .header(reqwest::header::ACCEPT, "application/json")
            .query(&[
                ("start", start.to_string()),
                ("limit", PAGE_LIMIT.to_string()),
                ("startDate", from.to_string()),
                ("endDate", to.to_string()),
            ])
            .send()
            .await
            .map_err(|err| {
                error!("garmin activities request failed: {err}");
                ActivityClientError
            })
    }
}

#[async_trait]
impl ActivityClient for GarminClient {
    async fn summaries(
        &self,
        from: NaiveDate,
        to: NaiveDate,
    ) -> Result<Vec<ActivitySummary>, ActivityClientError> {
        let mut seen = HashSet::new();
        let mut collected = Vec::new();
        let mut start = 0i64;
        for page_index in 0..MAX_PAGES {
            let page = self.page_summaries(from, to, start).await?;
            let len = page.len;
            let fresh = page
                .summaries
                .into_iter()
                .filter(|summary| seen.insert(summary.source.clone()));
            let fresh_count = {
                let before = collected.len();
                collected.extend(fresh);
                collected.len() - before
            };
            if fresh_count == 0 && len > 0 && start > 0 {
                break;
            }
            if (len as i64) < PAGE_LIMIT {
                break;
            }
            if page_index + 1 == MAX_PAGES {
                warn!("stopped reading garmin activities after {MAX_PAGES} pages");
            }
            start += len as i64;
        }
        Ok(collected)
    }
}

fn kind_of(type_key: &str) -> ActivityKind {
    let key = type_key.trim().to_ascii_lowercase();
    if key == "running" || key.ends_with("_running") {
        return ActivityKind::Run;
    }
    if key == "bmx" || key == "cyclocross" || key.contains("cycling") || key.contains("biking") {
        return ActivityKind::Ride;
    }
    if key.contains("cross_country") && key.contains("ski") {
        return ActivityKind::Ski;
    }
    ActivityKind::Other
}

fn parse_activity_summaries(body: &str) -> Result<ParsedPage, ActivityClientError> {
    let value: serde_json::Value = serde_json::from_str(body).map_err(|err| {
        error!("garmin activities were not json: {err}");
        ActivityClientError
    })?;
    let Some(items) = value.as_array() else {
        error!("garmin activities were not a list");
        return Err(ActivityClientError);
    };
    let mut summaries = Vec::new();
    for item in items {
        match summary_from_activity(item) {
            Some(summary) => summaries.push(summary),
            None => warn!("skipping a garmin activity that has no id or local time"),
        }
    }
    Ok(ParsedPage {
        summaries,
        len: items.len(),
    })
}

fn summary_from_activity(item: &serde_json::Value) -> Option<ActivitySummary> {
    let activity: GarminActivity = serde_json::from_value(item.clone()).ok()?;
    let activity_id = activity_id(activity.activity_id.as_ref()?)?;
    let local_start = parse_local(activity.start_time_local.as_deref()?)?;
    let type_key = activity
        .activity_type
        .and_then(|activity_type| activity_type.type_key)
        .unwrap_or_default();
    Some(ActivitySummary {
        source: ActivitySource {
            provider: ActivityProvider::Garmin,
            activity_id,
        },
        name: activity_name(activity.activity_name.as_deref(), &type_key),
        local_start,
        distance_metres: activity.distance,
        duration_seconds: activity.duration,
        kind: kind_of(&type_key),
    })
}

fn activity_name(name: Option<&str>, type_key: &str) -> String {
    let name = name.unwrap_or("").trim();
    if !name.is_empty() {
        return name.to_string();
    }
    let type_key = type_key.trim();
    if !type_key.is_empty() {
        return type_key.to_string();
    }
    "Untitled activity".to_string()
}

fn activity_id(value: &serde_json::Value) -> Option<String> {
    match value {
        serde_json::Value::Number(number) => {
            if let Some(id) = number.as_i64() {
                if id >= 0 {
                    return Some(id.to_string());
                }
            }
            number.as_u64().map(|id| id.to_string())
        }
        serde_json::Value::String(text) => {
            let text = text.trim();
            if text.is_empty() {
                None
            } else {
                Some(text.to_string())
            }
        }
        _ => None,
    }
}

fn parse_local(value: &str) -> Option<NaiveDateTime> {
    let value = value.trim();
    let formats = [
        "%Y-%m-%d %H:%M:%S%.f",
        "%Y-%m-%dT%H:%M:%S%.f",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
    ];
    for format in formats {
        if let Ok(parsed) = NaiveDateTime::parse_from_str(value, format) {
            return Some(parsed);
        }
    }
    NaiveDate::parse_from_str(value, "%Y-%m-%d")
        .ok()
        .and_then(|date| date.and_hms_opt(0, 0, 0))
}

fn access_token(body: &str) -> Option<String> {
    let body = body.trim();
    if body.is_empty() {
        return None;
    }
    let token = if body.starts_with('{') {
        let value: serde_json::Value = serde_json::from_str(body).ok()?;
        value.get("access_token")?.as_str()?.trim().to_string()
    } else {
        body.trim_matches('"').trim().to_string()
    };
    let trimmed = token.trim();
    let token = trimmed.strip_prefix("Bearer ").unwrap_or(trimmed).trim();
    if token.is_empty() {
        None
    } else {
        Some(token.to_string())
    }
}

fn token_expiry(token: &str) -> Option<DateTime<Utc>> {
    let payload = token.split('.').nth(1)?;
    let bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(payload)
        .ok()?;
    let value: serde_json::Value = serde_json::from_slice(&bytes).ok()?;
    let exp = value.get("exp")?.as_i64()?;
    DateTime::from_timestamp(exp, 0)
}

fn refresh_at(token: &str) -> DateTime<Utc> {
    token_expiry(token)
        .map(|exp| exp - Duration::minutes(5))
        .unwrap_or_else(|| Utc::now() + Duration::hours(23))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GarminActivity {
    #[serde(default)]
    activity_id: Option<serde_json::Value>,
    #[serde(default)]
    activity_name: Option<String>,
    #[serde(default)]
    start_time_local: Option<String>,
    #[serde(default)]
    activity_type: Option<GarminActivityType>,
    #[serde(default)]
    distance: Option<f64>,
    #[serde(default)]
    duration: Option<f64>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GarminActivityType {
    #[serde(default)]
    type_key: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn garmin_type_keys_map_onto_run_ride_and_ski() {
        for key in [
            "running",
            "trail_running",
            "treadmill_running",
            "virtual_running",
            "indoor_running",
        ] {
            assert_eq!(kind_of(key), ActivityKind::Run, "{key}");
        }
        for key in [
            "cycling",
            "gravel_cycling",
            "mountain_biking",
            "indoor_cycling",
            "e_biking",
            "cyclocross",
            "bmx",
            "handcycling",
        ] {
            assert_eq!(kind_of(key), ActivityKind::Ride, "{key}");
        }
        for key in [
            "cross_country_skiing",
            "cross_country_classic_skiing",
            "cross_country_skate_skiing",
        ] {
            assert_eq!(kind_of(key), ActivityKind::Ski, "{key}");
        }
        for key in [
            "strength_training",
            "backcountry_skiing",
            "resort_skiing",
            "swimming",
            "hiking",
        ] {
            assert_eq!(kind_of(key), ActivityKind::Other, "{key}");
        }
    }

    #[test]
    fn a_fixture_list_keeps_the_local_date_and_the_provider() {
        let body = r#"[
            {
                "activityId": 100,
                "activityName": "Morning run",
                "startTimeLocal": "2026-11-06 23:40:00",
                "activityType": { "typeKey": "trail_running" },
                "distance": 10234.6,
                "duration": 3120.4
            },
            {
                "activityId": 300,
                "activityName": "Nordmarka",
                "startTimeLocal": "2026-11-07T10:15:00",
                "activityType": { "typeKey": "cross_country_classic_skiing" },
                "distance": 12000,
                "duration": 3600
            },
            {
                "activityId": 200,
                "activityName": "Strength",
                "startTimeLocal": "2026-11-06 18:00:00",
                "activityType": { "typeKey": "strength_training" },
                "duration": 2400
            }
        ]"#;

        let page = parse_activity_summaries(body).unwrap();
        assert_eq!(page.len, 3);
        assert_eq!(page.summaries[0].kind, ActivityKind::Run);
        assert_eq!(
            page.summaries[0].local_start.date(),
            NaiveDate::from_ymd_opt(2026, 11, 6).unwrap()
        );
        assert_eq!(page.summaries[0].source.provider.as_str(), "garmin");
        assert_eq!(page.summaries[0].source.activity_id, "100");
        assert_eq!(page.summaries[1].kind, ActivityKind::Ski);
        assert_eq!(page.summaries[2].kind, ActivityKind::Other);
        assert_eq!(page.summaries[2].name, "Strength");
    }

    #[test]
    fn token_expiry_reads_the_exp_claim() {
        let payload =
            base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(r#"{"exp":1700000000}"#);
        let token = format!("header.{payload}.sig");
        assert_eq!(
            token_expiry(&token),
            DateTime::from_timestamp(1_700_000_000, 0)
        );
    }

    #[test]
    fn access_token_reads_a_raw_jwt_or_a_json_body() {
        assert_eq!(
            access_token("  raw.jwt.token\n").as_deref(),
            Some("raw.jwt.token")
        );
        assert_eq!(
            access_token(r#"{"access_token":"Bearer json.jwt.token"}"#).as_deref(),
            Some("json.jwt.token")
        );
        assert_eq!(access_token("   "), None);
    }

    #[tokio::test]
    async fn a_missing_key_does_not_call_garmin() {
        let client = GarminClient::new(String::new());
        let today = NaiveDate::from_ymd_opt(2026, 11, 8).unwrap();
        let result = client.summaries(today, today).await;
        assert!(result.is_err());
    }
}
