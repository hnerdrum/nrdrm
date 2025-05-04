use chrono::prelude::*;
use diesel::prelude::*;
use uuid::Uuid;
use super::{error::DatabaseError, schema::user_account};
use deadpool_diesel::postgres::Pool;

#[derive(Clone, Debug, Queryable, Selectable)]
#[diesel(table_name = user_account)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct DbUserAccount {
  pub id: Uuid,
  pub created_at: DateTime<Utc>,
  pub updated_at: DateTime<Utc>,
  pub email: String,
  pub password_hash: String,
}

pub async fn find_user_by_id(pool: &Pool, user_id: Uuid) -> Result<DbUserAccount, DatabaseError> {
  let conn = pool.get().await.map_err(|_| DatabaseError::UnknownError)?;
  conn.interact(move |conn| {
    let query = user_account::table.into_boxed::<diesel::pg::Pg>();
    query
      .filter(user_account::id.eq(user_id))
      .select(DbUserAccount::as_select())
      .first::<DbUserAccount>(conn).map_err(|_| DatabaseError::NotFoundError)
  }).await.map_err(|_| DatabaseError::UnknownError).unwrap_or_else(|_| Err(DatabaseError::UnknownError))
}

pub async fn find_user_by_email(pool: &Pool, email: String) -> Result<DbUserAccount, DatabaseError> {
  let conn = pool.get().await.map_err(|_| DatabaseError::UnknownError)?;
  conn.interact(move |conn| {
    let query = user_account::table.into_boxed::<diesel::pg::Pg>();
    query
      .filter(user_account::email.eq(email))
      .select(DbUserAccount::as_select())
      .first::<DbUserAccount>(conn).map_err(|_| DatabaseError::NotFoundError)
  }).await.map_err(|_| DatabaseError::UnknownError).unwrap_or_else(|_| Err(DatabaseError::UnknownError))
}