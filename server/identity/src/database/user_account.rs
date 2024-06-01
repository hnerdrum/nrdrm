use chrono::prelude::*;
use diesel::prelude::*;
use uuid::Uuid;
use super::schema::user_account;
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

pub async fn find_all(pool: &Pool)  -> Result<Vec<DbUserAccount>, String> {
  let conn = pool.get().await.map_err(|_| "Failed to get connection")?;

  conn.interact(move |conn| {
    let query = user_account::table.into_boxed::<diesel::pg::Pg>();
    query.select(DbUserAccount::as_select()).load::<DbUserAccount>(conn).map_err(|_| "Failed to load users".to_string())
  }).await.map_err(|_| "Failed to load users".to_string()).unwrap_or_else(|_| Ok(Vec::new()))
}

pub async fn find_by_email(pool: &Pool, email: String) -> Result<DbUserAccount, String> {
  let conn = pool.get().await.map_err(|_| "Failed to get connection")?;
  conn.interact(move |conn| {
    let query = user_account::table.into_boxed::<diesel::pg::Pg>();
    query
      .filter(user_account::email.eq(email))
      .select(DbUserAccount::as_select())
      .first::<DbUserAccount>(conn).map_err(|_| "Failed to find user".to_string())
  }).await.map_err(|_| "Failed to find user".to_string()).unwrap_or_else(|_| Err("Failed to find user".to_string()))
}