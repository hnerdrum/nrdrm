use chrono::prelude::*;
use diesel::prelude::*;
use diesel::PgConnection;
use uuid::Uuid;

use super::{
    access_token::{insert_access_token_on, NewAccessToken},
    error::DatabaseError,
    schema::refresh_token,
};
use deadpool_diesel::postgres::Pool;

#[derive(Clone, Debug, Queryable, Selectable)]
#[diesel(table_name = refresh_token)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct RefreshToken {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub token_hash: String,
    pub client_id: Uuid,
    pub user_id: Uuid,
    pub resource: String,
    pub scope: String,
    pub family_id: Uuid,
    pub expires_at: DateTime<Utc>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub replaced_by: Option<Uuid>,
}

pub struct NewRefreshToken {
    pub token_hash: String,
    pub client_id: Uuid,
    pub user_id: Uuid,
    pub resource: String,
    pub scope: String,
    pub family_id: Uuid,
    pub expires_at: DateTime<Utc>,
}

pub enum Rotation {
    Rotated,
    LostRace,
}

pub async fn find_refresh_token_by_hash(
    pool: &Pool,
    token_hash: String,
) -> Result<RefreshToken, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        refresh_token::table
            .filter(refresh_token::token_hash.eq(token_hash))
            .first(conn)
            .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

pub async fn insert_token_pair(
    pool: &Pool,
    access: NewAccessToken,
    refresh: NewRefreshToken,
) -> Result<(), DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        conn.transaction(|conn| {
            insert_access_token_on(conn, access)?;
            insert_refresh_token_on(conn, refresh)?;
            Ok(())
        })
        .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

/// Retires `previous_id` only if it is still unused. A lost race rolls back the new pair.
pub async fn rotate_refresh_token(
    pool: &Pool,
    previous_id: Uuid,
    access: NewAccessToken,
    refresh: NewRefreshToken,
) -> Result<Rotation, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| rotate_conn(conn, previous_id, access, refresh))
        .await
        .map_err(|_| DatabaseError::UnknownError)?
}

pub async fn revoke_refresh_family(pool: &Pool, family_id: Uuid) -> Result<(), DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        diesel::update(
            refresh_token::table
                .filter(refresh_token::family_id.eq(family_id))
                .filter(refresh_token::revoked_at.is_null()),
        )
        .set((
            refresh_token::revoked_at.eq(Utc::now()),
            refresh_token::updated_at.eq(Utc::now()),
        ))
        .execute(conn)
        .map(|_| ())
        .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

fn insert_refresh_token_on(
    conn: &mut PgConnection,
    token: NewRefreshToken,
) -> QueryResult<RefreshToken> {
    diesel::insert_into(refresh_token::table)
        .values((
            refresh_token::token_hash.eq(token.token_hash),
            refresh_token::client_id.eq(token.client_id),
            refresh_token::user_id.eq(token.user_id),
            refresh_token::resource.eq(token.resource),
            refresh_token::scope.eq(token.scope),
            refresh_token::family_id.eq(token.family_id),
            refresh_token::expires_at.eq(token.expires_at),
        ))
        .get_result(conn)
}

fn rotate_conn(
    conn: &mut PgConnection,
    previous_id: Uuid,
    access: NewAccessToken,
    refresh: NewRefreshToken,
) -> Result<Rotation, DatabaseError> {
    match conn.transaction(|conn| {
        insert_access_token_on(conn, access)?;
        let created = insert_refresh_token_on(conn, refresh)?;
        let updated = diesel::update(
            refresh_token::table
                .filter(refresh_token::id.eq(previous_id))
                .filter(refresh_token::revoked_at.is_null())
                .filter(refresh_token::replaced_by.is_null()),
        )
        .set((
            refresh_token::revoked_at.eq(Utc::now()),
            refresh_token::replaced_by.eq(created.id),
            refresh_token::updated_at.eq(Utc::now()),
        ))
        .execute(conn)?;
        if updated == 0 {
            return Err(diesel::result::Error::RollbackTransaction);
        }
        Ok(())
    }) {
        Ok(()) => Ok(Rotation::Rotated),
        Err(diesel::result::Error::RollbackTransaction) => Ok(Rotation::LostRace),
        Err(err) => Err(DatabaseError::from_diesel(err)),
    }
}
