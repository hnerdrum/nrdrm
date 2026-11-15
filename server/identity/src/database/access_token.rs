use chrono::prelude::*;
use diesel::prelude::*;
use diesel::PgConnection;
use uuid::Uuid;

use super::{error::DatabaseError, schema::access_token};
use deadpool_diesel::postgres::Pool;

#[derive(Clone, Debug, Queryable, Selectable)]
#[diesel(table_name = access_token)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct AccessToken {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub token_hash: String,
    pub client_id: Uuid,
    pub audience: String,
    pub expires_at: DateTime<Utc>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub user_id: Option<Uuid>,
    pub scope: Option<String>,
}

pub struct NewAccessToken {
    pub token_hash: String,
    pub client_id: Uuid,
    pub audience: String,
    pub expires_at: DateTime<Utc>,
    pub user_id: Option<Uuid>,
    pub scope: Option<String>,
}

pub async fn find_access_token_by_hash(
    pool: &Pool,
    token_hash: String,
) -> Result<AccessToken, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        access_token::table
            .filter(access_token::token_hash.eq(token_hash))
            .first(conn)
            .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

pub fn insert_access_token_on(
    conn: &mut PgConnection,
    token: NewAccessToken,
) -> QueryResult<AccessToken> {
    diesel::insert_into(access_token::table)
        .values((
            access_token::token_hash.eq(token.token_hash),
            access_token::client_id.eq(token.client_id),
            access_token::audience.eq(token.audience),
            access_token::expires_at.eq(token.expires_at),
            access_token::user_id.eq(token.user_id),
            access_token::scope.eq(token.scope),
        ))
        .get_result(conn)
}

pub async fn insert_access_token(
    pool: &Pool,
    token: NewAccessToken,
) -> Result<AccessToken, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        insert_access_token_on(conn, token).map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}
