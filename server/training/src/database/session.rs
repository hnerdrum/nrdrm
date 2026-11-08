use std::collections::{HashMap, HashSet};

use chrono::{DateTime, NaiveDate, Utc};
use deadpool_diesel::postgres::Pool;
use diesel::prelude::*;
use diesel::result::DatabaseErrorKind;
use diesel::PgConnection;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tracing::{debug, error};
use uuid::Uuid;

use super::schema::{session, session_source};
use crate::domain::import::PlannedSession;
use crate::domain::session::{SessionBody, Sport};
use crate::domain::source::{ActivityProvider, ActivitySource};

#[derive(Debug)]
pub enum SessionStoreError {
    NotFound,
    Connection,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Session {
    pub id: Uuid,
    pub on_date: NaiveDate,
    pub body: SessionBody,
    pub source: Option<ActivitySource>,
}

#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = session)]
#[diesel(check_for_backend(diesel::pg::Pg))]
struct SessionRow {
    id: Uuid,
    on_date: NaiveDate,
    body: Value,
}

#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = session_source)]
#[diesel(check_for_backend(diesel::pg::Pg))]
struct SourceRow {
    session_id: Uuid,
    provider: ActivityProvider,
    activity_id: String,
}

pub async fn create(
    pool: &Pool,
    on_date: NaiveDate,
    body: SessionBody,
) -> Result<Session, SessionStoreError> {
    let body = to_json(body)?;
    run(pool, move |conn| {
        diesel::insert_into(session::table)
            .values((session::on_date.eq(on_date), session::body.eq(body)))
            .returning(SessionRow::as_returning())
            .get_result(conn)
            .map_err(store_err)
            .and_then(|row| from_row(row, None))
    })
    .await
}

pub async fn list(
    pool: &Pool,
    from: NaiveDate,
    to: NaiveDate,
) -> Result<Vec<Session>, SessionStoreError> {
    run(pool, move |conn| {
        session::table
            .filter(session::deleted_at.is_null())
            .filter(session::on_date.ge(from))
            .filter(session::on_date.le(to))
            .order((session::on_date.asc(), session::id.asc()))
            .select(SessionRow::as_select())
            .load(conn)
            .map_err(store_err)
            .and_then(|rows| attach_sources(conn, rows))
    })
    .await
}

pub async fn latest(
    pool: &Pool,
    sport: Sport,
    through: NaiveDate,
) -> Result<Option<Session>, SessionStoreError> {
    let sport = sport.as_str();
    run(pool, move |conn| {
        let row = session::table
            .filter(session::deleted_at.is_null())
            .filter(session::on_date.le(through))
            .filter(session::body.retrieve_as_text("sport").eq(sport))
            .order((session::on_date.desc(), session::id.desc()))
            .select(SessionRow::as_select())
            .first(conn)
            .optional()
            .map_err(store_err)?;
        row.map(|row| one(conn, row)).transpose()
    })
    .await
}

pub async fn find(pool: &Pool, id: Uuid) -> Result<Session, SessionStoreError> {
    run(pool, move |conn| {
        session::table
            .filter(session::deleted_at.is_null())
            .filter(session::id.eq(id))
            .select(SessionRow::as_select())
            .first(conn)
            .map_err(store_err)
            .and_then(|row| one(conn, row))
    })
    .await
}

pub async fn update(
    pool: &Pool,
    id: Uuid,
    on_date: NaiveDate,
    body: SessionBody,
) -> Result<Session, SessionStoreError> {
    let body = to_json(body)?;
    run(pool, move |conn| {
        diesel::update(
            session::table
                .filter(session::deleted_at.is_null())
                .filter(session::id.eq(id)),
        )
        .set((session::on_date.eq(on_date), session::body.eq(body)))
        .returning(SessionRow::as_returning())
        .get_result(conn)
        .map_err(store_err)
        .and_then(|row| one(conn, row))
    })
    .await
}

pub async fn stored_sources(pool: &Pool) -> Result<HashSet<ActivitySource>, SessionStoreError> {
    run(pool, |conn| {
        let rows: Vec<(ActivityProvider, String)> = session_source::table
            .select((session_source::provider, session_source::activity_id))
            .load(conn)
            .map_err(store_err)?;
        rows.into_iter()
            .map(|(provider, activity_id)| source_from(provider, activity_id))
            .collect()
    })
    .await
}

pub async fn insert_imported(
    pool: &Pool,
    planned: Vec<PlannedSession>,
) -> Result<Vec<Session>, SessionStoreError> {
    if planned.is_empty() {
        return Ok(Vec::new());
    }
    run(pool, move |conn| {
        let mut saved = Vec::with_capacity(planned.len());
        for item in planned {
            let body = to_json(item.body)?;
            let source = item.source;
            let activity_id = source.activity_id.clone();
            let inserted = conn.transaction(|conn| {
                let row = diesel::insert_into(session::table)
                    .values((session::on_date.eq(item.on_date), session::body.eq(&body)))
                    .returning(SessionRow::as_returning())
                    .get_result(conn)?;
                diesel::insert_into(session_source::table)
                    .values((
                        session_source::session_id.eq(row.id),
                        session_source::provider.eq(source.provider),
                        session_source::activity_id.eq(&activity_id),
                    ))
                    .execute(conn)?;
                Ok(row)
            });
            match inserted {
                Ok(row) => saved.push(from_row(row, Some(source))?),
                Err(diesel::result::Error::DatabaseError(
                    DatabaseErrorKind::UniqueViolation,
                    _,
                )) => {
                    debug!(
                        "activity {}/{activity_id} is already stored",
                        source.provider.as_str()
                    );
                }
                Err(err) => return Err(store_err(err)),
            }
        }
        Ok(saved)
    })
    .await
}

pub async fn delete(pool: &Pool, id: Uuid) -> Result<(), SessionStoreError> {
    let now: DateTime<Utc> = Utc::now();
    run(pool, move |conn| {
        let deleted = diesel::update(
            session::table
                .filter(session::deleted_at.is_null())
                .filter(session::id.eq(id)),
        )
        .set(session::deleted_at.eq(now))
        .execute(conn)
        .map_err(store_err)?;
        if deleted == 0 {
            Err(SessionStoreError::NotFound)
        } else {
            Ok(())
        }
    })
    .await
}

async fn run<T, F>(pool: &Pool, f: F) -> Result<T, SessionStoreError>
where
    T: Send + 'static,
    F: FnOnce(&mut PgConnection) -> Result<T, SessionStoreError> + Send + 'static,
{
    let conn = pool.get().await.map_err(|err| {
        error!("session connection failed: {err:?}");
        SessionStoreError::Connection
    })?;
    conn.interact(f).await.map_err(|err| {
        error!("session query failed: {err:?}");
        SessionStoreError::Unknown
    })?
}

fn to_json(body: SessionBody) -> Result<Value, SessionStoreError> {
    serde_json::to_value(body).map_err(|err| {
        error!("session body failed to serialize: {err}");
        SessionStoreError::Unknown
    })
}

fn one(conn: &mut PgConnection, row: SessionRow) -> Result<Session, SessionStoreError> {
    let id = row.id;
    let source = sources_for(conn, &[id])?.remove(&id);
    from_row(row, source)
}

fn attach_sources(
    conn: &mut PgConnection,
    rows: Vec<SessionRow>,
) -> Result<Vec<Session>, SessionStoreError> {
    let ids: Vec<Uuid> = rows.iter().map(|row| row.id).collect();
    let mut sources = sources_for(conn, &ids)?;
    rows.into_iter()
        .map(|row| {
            let source = sources.remove(&row.id);
            from_row(row, source)
        })
        .collect()
}

fn sources_for(
    conn: &mut PgConnection,
    ids: &[Uuid],
) -> Result<HashMap<Uuid, ActivitySource>, SessionStoreError> {
    if ids.is_empty() {
        return Ok(HashMap::new());
    }
    let rows: Vec<SourceRow> = session_source::table
        .filter(session_source::session_id.eq_any(ids))
        .select(SourceRow::as_select())
        .load(conn)
        .map_err(store_err)?;
    rows.into_iter()
        .map(|row| {
            source_from(row.provider, row.activity_id).map(|source| (row.session_id, source))
        })
        .collect()
}

fn from_row(row: SessionRow, source: Option<ActivitySource>) -> Result<Session, SessionStoreError> {
    let body = serde_json::from_value(row.body).map_err(|err| {
        error!("stored session {} has an unreadable body: {err}", row.id);
        SessionStoreError::Unknown
    })?;
    Ok(Session {
        id: row.id,
        on_date: row.on_date,
        body,
        source,
    })
}

fn source_from(
    provider: ActivityProvider,
    activity_id: String,
) -> Result<ActivitySource, SessionStoreError> {
    if activity_id.is_empty() {
        error!("stored activity id is empty");
        return Err(SessionStoreError::Unknown);
    }
    Ok(ActivitySource {
        provider,
        activity_id,
    })
}

fn store_err(err: diesel::result::Error) -> SessionStoreError {
    match err {
        diesel::result::Error::NotFound => SessionStoreError::NotFound,
        other => {
            error!("session query failed: {other:?}");
            SessionStoreError::Unknown
        }
    }
}
