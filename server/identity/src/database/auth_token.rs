use std::io::Write;

use chrono::prelude::*;
use diesel::{deserialize::{self, FromSql, FromSqlRow}, expression::AsExpression, pg::Pg, prelude::*, serialize::{self, IsNull, Output, ToSql}, upsert::excluded};
use uuid::Uuid;
use crate::domain::model::User;

use super::{error::DatabaseError, schema::{auth_token, sql_types}};
use deadpool_diesel::postgres::Pool;

#[derive(Debug, Clone, PartialEq, AsExpression, FromSqlRow)]
#[diesel(sql_type = sql_types::TokenStatus)]
pub enum TokenStatus {
    Normal,
    Withdrawn,
    Expired,
}

impl FromSql<sql_types::TokenStatus, Pg> for TokenStatus {
  fn from_sql(bytes: <Pg as diesel::backend::Backend>::RawValue<'_>) -> deserialize::Result<Self> {
      match std::str::from_utf8(bytes.as_bytes())? {
          "NORMAL" => Ok(TokenStatus::Normal),
          "WITHDRAWN" => Ok(TokenStatus::Withdrawn),
          "EXPIRED" => Ok(TokenStatus::Expired),
          v => Err(format!("Unrecognized enum variant: {}", v).into()),
      }
  }
}

impl ToSql<sql_types::TokenStatus, Pg> for TokenStatus {
  fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
      match *self {
          TokenStatus::Normal => out.write_all(b"NORMAL")?,
          TokenStatus::Withdrawn => out.write_all(b"WITHDRAWN")?,
          TokenStatus::Expired => out.write_all(b"EXPIRED")?,
      }
      Ok(IsNull::No)
  }
}

#[derive(Clone, Debug, Queryable, Selectable)]
#[diesel(table_name = auth_token)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct DbAuthToken {
  pub id: Uuid,
  pub created_at: DateTime<Utc>,
  pub updated_at: DateTime<Utc>,
  pub value: String,
  pub status: TokenStatus,
  pub user_id: Uuid,
}


pub async fn find_auth_token(pool: &Pool, value: String) -> Result<DbAuthToken, DatabaseError> {
  let conn = pool.get().await.map_err(|_| DatabaseError::ConnectionError)?;

  conn.interact(move |conn| {
    auth_token::table
      .filter(auth_token::value.eq(value))
      .filter(auth_token::status.eq(TokenStatus::Normal))
      .first::<DbAuthToken>(conn).map_err(|err| match err {
        diesel::result::Error::NotFound => DatabaseError::NotFoundError,
        _ => DatabaseError::UnknownError,
      })
  })
  .await
  .map_err(|_| DatabaseError::UnknownError)?
}

pub async fn upsert_user_auth_token(pool: &Pool, user: User, token: String) -> Result<(), DatabaseError> {
  let conn = pool.get().await.map_err(|_| DatabaseError::ConnectionError)?;

  let now = Utc::now();

  conn.interact(move |conn| {
    diesel::insert_into(auth_token::table)
      .values((
          auth_token::value.eq(token),
          auth_token::status.eq(TokenStatus::Normal),
          auth_token::user_id.eq(user.id)
      ))
      .on_conflict((auth_token::value, auth_token::user_id))
      .do_update()
      .set((
          auth_token::status.eq(excluded(auth_token::status)),
          auth_token::updated_at.eq(now)
      ))
      .execute(conn)
      .map(|_| ())
      .map_err(|_| DatabaseError::UnknownError)
    
  }).await
  .map_err(|_| DatabaseError::UnknownError)?
}
