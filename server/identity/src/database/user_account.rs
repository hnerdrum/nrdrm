use super::{error::DatabaseError, schema::user_account};
use chrono::prelude::*;
use deadpool_diesel::postgres::Pool;
use diesel::prelude::*;
use uuid::Uuid;

#[derive(Clone, Debug, Queryable, Selectable)]
#[diesel(table_name = user_account)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct UserAccount {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub email: String,
    pub password_hash: String,
}

pub async fn find_user_by_email(pool: &Pool, email: String) -> Result<UserAccount, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        user_account::table
            .filter(user_account::email.eq(email))
            .first(conn)
            .map_err(|err| match err {
                diesel::result::Error::NotFound => DatabaseError::NotFoundError,
                _ => DatabaseError::UnknownError,
            })
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

pub async fn create_user(
    pool: &Pool,
    email: String,
    password_hash: String,
) -> Result<(), DatabaseError> {
    match find_user_by_email(pool, email.clone()).await {
        Ok(_) => return Err(DatabaseError::AlreadyExists),
        Err(DatabaseError::NotFoundError) => {}
        Err(err) => return Err(err),
    }

    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        diesel::insert_into(user_account::table)
            .values((
                user_account::email.eq(email),
                user_account::password_hash.eq(password_hash),
            ))
            .execute(conn)
            .map(|_| ())
            .map_err(DatabaseError::from_diesel)
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}

pub async fn find_user_by_id(pool: &Pool, id: Uuid) -> Result<UserAccount, DatabaseError> {
    let conn = pool
        .get()
        .await
        .map_err(|_| DatabaseError::ConnectionError)?;

    conn.interact(move |conn| {
        user_account::table
            .filter(user_account::id.eq(id))
            .first(conn)
            .map_err(|err| match err {
                diesel::result::Error::NotFound => DatabaseError::NotFoundError,
                _ => DatabaseError::UnknownError,
            })
    })
    .await
    .map_err(|_| DatabaseError::UnknownError)?
}
