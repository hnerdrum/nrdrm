use std::io::Write;

use chrono::{prelude::*, Duration};
use diesel::{deserialize::{self, FromSql, FromSqlRow}, expression::AsExpression, pg::Pg, prelude::*, serialize::{self, IsNull, Output, ToSql}};
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
pub struct AuthToken {
  pub id: Uuid,
  pub created_at: DateTime<Utc>,
  pub updated_at: DateTime<Utc>,
  pub status: TokenStatus,
  pub user_id: Uuid,
  pub expires_at: DateTime<Utc>,
  pub issued_at: DateTime<Utc>
}

pub async fn create_auth_token(pool: &Pool, user: User) -> Result<AuthToken, DatabaseError> {
  let conn = pool.get().await.map_err(|_| DatabaseError::ConnectionError)?;

  let now = Utc::now();

  conn.interact(move |conn| {
    diesel::insert_into(auth_token::table)
      .values((
          auth_token::status.eq(TokenStatus::Normal),
          auth_token::user_id.eq(user.id),
          auth_token::issued_at.eq(now),
          auth_token::expires_at.eq(get_expiry()),
      ))
      .get_result(conn)
      .map_err(|_| DatabaseError::UnknownError)
    
  }).await
  .map_err(|_| DatabaseError::UnknownError)?
}

fn get_expiry() -> DateTime<Utc> {
    const EXPIRY_TIME_AM: u32 = 3;
    let now = Utc::now();

    // If it's after 3am, set target date as tomorrow
    let target_date = if now.hour() < EXPIRY_TIME_AM {
      now.date_naive()
    } else {
        (now + Duration::days(1)).date_naive()
    };

    Utc.with_ymd_and_hms(
      target_date.year(),
      target_date.month(),
      target_date.day(),
      EXPIRY_TIME_AM,
      0,
      0,
  ).unwrap()
}
