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

pub async fn find_user_by_email(pool: &Pool, email: String) -> Result<DbUserAccount, DatabaseError> {
  let conn = pool.get().await.map_err(|_| DatabaseError::ConnectionError)?;

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