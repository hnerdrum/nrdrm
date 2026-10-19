use chrono::prelude::*;
use diesel::prelude::*;
use uuid::Uuid;

use super::{
    error::DatabaseError,
    schema::{oauth_client, oauth_client_audience},
};
use deadpool_diesel::postgres::Pool;

#[derive(Clone, Debug, Queryable, Selectable)]
#[diesel(table_name = oauth_client)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct OauthClient {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub name: String,
    pub secret_hash: String,
}

pub async fn find_client_by_id(pool: &Pool, id: Uuid) -> Result<OauthClient, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        oauth_client::table
            .filter(oauth_client::id.eq(id))
            .first(conn)
            .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

pub async fn client_has_audience(
    pool: &Pool,
    client_id: Uuid,
    audience: String,
) -> Result<bool, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        oauth_client_audience::table
            .filter(oauth_client_audience::client_id.eq(client_id))
            .filter(oauth_client_audience::audience.eq(audience))
            .select(oauth_client_audience::audience)
            .first::<String>(conn)
            .optional()
            .map(|row| row.is_some())
            .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

pub async fn insert_client(
    pool: &Pool,
    name: String,
    secret_hash: String,
    audience: String,
) -> Result<OauthClient, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        conn.transaction(|conn| {
            let client = diesel::insert_into(oauth_client::table)
                .values((
                    oauth_client::name.eq(name),
                    oauth_client::secret_hash.eq(secret_hash),
                ))
                .get_result::<OauthClient>(conn)?;
            diesel::insert_into(oauth_client_audience::table)
                .values((
                    oauth_client_audience::client_id.eq(client.id),
                    oauth_client_audience::audience.eq(audience),
                ))
                .execute(conn)?;
            Ok(client)
        })
        .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}
