use chrono::prelude::*;
use diesel::prelude::*;
use uuid::Uuid;

use super::{error::DatabaseError, schema::authorization_code};
use deadpool_diesel::postgres::Pool;

#[derive(Clone, Debug, Queryable, Selectable)]
#[diesel(table_name = authorization_code)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct AuthorizationCode {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub code_hash: String,
    pub client_id: Uuid,
    pub user_id: Uuid,
    pub redirect_uri: String,
    pub code_challenge: String,
    pub resource: String,
    pub scope: String,
    pub expires_at: DateTime<Utc>,
    pub used_at: Option<DateTime<Utc>>,
}

pub struct NewAuthorizationCode {
    pub code_hash: String,
    pub client_id: Uuid,
    pub user_id: Uuid,
    pub redirect_uri: String,
    pub code_challenge: String,
    pub resource: String,
    pub scope: String,
    pub expires_at: DateTime<Utc>,
}

pub async fn insert_authorization_code(
    pool: &Pool,
    code: NewAuthorizationCode,
) -> Result<(), DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        diesel::insert_into(authorization_code::table)
            .values((
                authorization_code::code_hash.eq(code.code_hash),
                authorization_code::client_id.eq(code.client_id),
                authorization_code::user_id.eq(code.user_id),
                authorization_code::redirect_uri.eq(code.redirect_uri),
                authorization_code::code_challenge.eq(code.code_challenge),
                authorization_code::resource.eq(code.resource),
                authorization_code::scope.eq(code.scope),
                authorization_code::expires_at.eq(code.expires_at),
            ))
            .execute(conn)
            .map(|_| ())
            .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}
