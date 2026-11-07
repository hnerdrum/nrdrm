use chrono::NaiveDate;
use deadpool_diesel::postgres::Pool;
use diesel::prelude::*;
use diesel::PgConnection;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tracing::error;
use uuid::Uuid;

use super::schema::session;
use crate::domain::session::SessionBody;

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
}

#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = session)]
#[diesel(check_for_backend(diesel::pg::Pg))]
struct SessionRow {
    id: Uuid,
    on_date: NaiveDate,
    body: Value,
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
            .and_then(from_row)
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
            .filter(session::on_date.ge(from))
            .filter(session::on_date.le(to))
            .order((session::on_date.asc(), session::id.asc()))
            .select(SessionRow::as_select())
            .load(conn)
            .map_err(store_err)?
            .into_iter()
            .map(from_row)
            .collect()
    })
    .await
}

pub async fn find(pool: &Pool, id: Uuid) -> Result<Session, SessionStoreError> {
    run(pool, move |conn| {
        session::table
            .filter(session::id.eq(id))
            .select(SessionRow::as_select())
            .first(conn)
            .map_err(store_err)
            .and_then(from_row)
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
        diesel::update(session::table.filter(session::id.eq(id)))
            .set((session::on_date.eq(on_date), session::body.eq(body)))
            .returning(SessionRow::as_returning())
            .get_result(conn)
            .map_err(store_err)
            .and_then(from_row)
    })
    .await
}

pub async fn delete(pool: &Pool, id: Uuid) -> Result<(), SessionStoreError> {
    run(pool, move |conn| {
        let deleted = diesel::delete(session::table.filter(session::id.eq(id)))
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

fn from_row(row: SessionRow) -> Result<Session, SessionStoreError> {
    let body = serde_json::from_value(row.body).map_err(|err| {
        error!("stored session {} has an unreadable body: {err}", row.id);
        SessionStoreError::Unknown
    })?;
    Ok(Session {
        id: row.id,
        on_date: row.on_date,
        body,
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
