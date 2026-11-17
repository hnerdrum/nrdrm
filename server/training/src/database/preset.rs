use chrono::Utc;
use deadpool_diesel::postgres::Pool;
use diesel::prelude::*;
use diesel::result::{DatabaseErrorKind, Error as DieselError};
use diesel::PgConnection;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tracing::error;
use uuid::Uuid;

use super::schema::training_preset as preset;
use crate::domain::session::{SessionBody, Sport};

diesel::define_sql_function! {
    /// Postgres `lower`, the same fold the unique name index uses.
    fn lower(text: diesel::sql_types::Text) -> diesel::sql_types::Text;
}

#[derive(Debug, PartialEq, Eq)]
pub enum PresetStoreError {
    NotFound,
    NameTaken,
    Connection,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Preset {
    pub id: Uuid,
    pub name: String,
    pub body: SessionBody,
}

#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = preset)]
#[diesel(check_for_backend(diesel::pg::Pg))]
struct PresetRow {
    id: Uuid,
    name: String,
    body: Value,
}

pub async fn create(
    pool: &Pool,
    name: String,
    body: SessionBody,
) -> Result<Preset, PresetStoreError> {
    let body = to_json(body)?;
    run(pool, move |conn| {
        diesel::insert_into(preset::table)
            .values((preset::name.eq(name), preset::body.eq(body)))
            .returning(PresetRow::as_returning())
            .get_result(conn)
            .map_err(store_err)
            .and_then(from_row)
    })
    .await
}

/// Every preset, or those of one sport: by sport (run, ride, ski, strength),
/// then by name regardless of case.
pub async fn list(pool: &Pool, sport: Option<Sport>) -> Result<Vec<Preset>, PresetStoreError> {
    let mut presets = run(pool, move |conn| {
        let mut query = preset::table.select(PresetRow::as_select()).into_boxed();
        if let Some(sport) = sport {
            query = query.filter(preset::body.retrieve_as_text("sport").eq(sport.as_str()));
        }
        query
            .load(conn)
            .map_err(store_err)?
            .into_iter()
            .map(from_row)
            .collect::<Result<Vec<_>, _>>()
    })
    .await?;
    presets.sort_by_cached_key(|preset| (sport_rank(&preset.body), preset.name.to_lowercase()));
    Ok(presets)
}

pub async fn find(pool: &Pool, id: Uuid) -> Result<Preset, PresetStoreError> {
    run(pool, move |conn| {
        preset::table
            .filter(preset::id.eq(id))
            .select(PresetRow::as_select())
            .first(conn)
            .map_err(store_err)
            .and_then(from_row)
    })
    .await
}

/// The preset with this name, regardless of case.
pub async fn find_by_name(pool: &Pool, name: String) -> Result<Preset, PresetStoreError> {
    run(pool, move |conn| {
        preset::table
            .filter(lower(preset::name).eq(lower(name)))
            .select(PresetRow::as_select())
            .first(conn)
            .map_err(store_err)
            .and_then(from_row)
    })
    .await
}

pub async fn update(
    pool: &Pool,
    id: Uuid,
    name: String,
    body: SessionBody,
) -> Result<Preset, PresetStoreError> {
    let body = to_json(body)?;
    let now = Utc::now();
    run(pool, move |conn| {
        diesel::update(preset::table.filter(preset::id.eq(id)))
            .set((
                preset::name.eq(name),
                preset::body.eq(body),
                preset::updated_at.eq(now),
            ))
            .returning(PresetRow::as_returning())
            .get_result(conn)
            .map_err(store_err)
            .and_then(from_row)
    })
    .await
}

pub async fn delete(pool: &Pool, id: Uuid) -> Result<(), PresetStoreError> {
    run(pool, move |conn| {
        let deleted = diesel::delete(preset::table.filter(preset::id.eq(id)))
            .execute(conn)
            .map_err(store_err)?;
        if deleted == 0 {
            Err(PresetStoreError::NotFound)
        } else {
            Ok(())
        }
    })
    .await
}

fn sport_rank(body: &SessionBody) -> u8 {
    match body {
        SessionBody::Run { .. } => 0,
        SessionBody::Ride { .. } => 1,
        SessionBody::Ski { .. } => 2,
        SessionBody::Strength { .. } => 3,
    }
}

async fn run<T, F>(pool: &Pool, f: F) -> Result<T, PresetStoreError>
where
    T: Send + 'static,
    F: FnOnce(&mut PgConnection) -> Result<T, PresetStoreError> + Send + 'static,
{
    let conn = pool.get().await.map_err(|err| {
        error!("preset connection failed: {err:?}");
        PresetStoreError::Connection
    })?;
    conn.interact(f).await.map_err(|err| {
        error!("preset query failed: {err:?}");
        PresetStoreError::Unknown
    })?
}

fn to_json(body: SessionBody) -> Result<Value, PresetStoreError> {
    serde_json::to_value(body).map_err(|err| {
        error!("preset body failed to serialize: {err}");
        PresetStoreError::Unknown
    })
}

fn from_row(row: PresetRow) -> Result<Preset, PresetStoreError> {
    let body = serde_json::from_value(row.body).map_err(|err| {
        error!("stored preset {} has an unreadable body: {err}", row.id);
        PresetStoreError::Unknown
    })?;
    Ok(Preset {
        id: row.id,
        name: row.name,
        body,
    })
}

fn store_err(err: DieselError) -> PresetStoreError {
    match err {
        DieselError::NotFound => PresetStoreError::NotFound,
        DieselError::DatabaseError(DatabaseErrorKind::UniqueViolation, info)
            if info.constraint_name() == Some("training_preset_name") =>
        {
            PresetStoreError::NameTaken
        }
        other => {
            error!("preset query failed: {other:?}");
            PresetStoreError::Unknown
        }
    }
}
