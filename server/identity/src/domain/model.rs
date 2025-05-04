use bcrypt::verify;
use serde::{Deserialize, Serialize};
use tracing::{error, info};
use uuid::Uuid;
use crate::database::error::DatabaseError;
use crate::database::user_account::{find_user_by_email, DbUserAccount};
use crate::database::connection::DBClient;

use super::error::DomainError;

#[derive(Serialize)]
pub struct TokenValidation {
    pub valid: bool,
}

#[derive(Serialize)]
pub struct UserSettings {
  pub auth: Option<Auth>
}

#[derive(Serialize, Clone)]
pub struct User {
  pub id: Uuid,
  pub email: String
}

#[derive(Serialize, Clone, Copy)]
pub struct Auth {
  pub user_id: Uuid,
}

#[derive(Deserialize, Debug)]
pub struct LoginInput {
  email: String,
  password: String,
}

pub async fn login_user(db: DBClient, input: LoginInput) -> Result<User, DomainError> {
  let user_account = find_user_by_email(&db, input.email.clone())
  .await
  .map_err(|err| match err {
    DatabaseError::NotFoundError => {
      info!("User not found for email {}", input.email.clone());
      DomainError::InvalidCredentialsError
    },
    err => {
      error!("Encountered unexpected database error: {:?}", err);
      DomainError::UnknownError
    }
  })?;

  verify_user_password(user_account, input.password)
    .map(|user| from_db_user(user))
}

fn verify_user_password(user_account: DbUserAccount, password: String) -> Result<DbUserAccount, DomainError> {
  verify(password, &user_account.password_hash)
    .map_err(|_| DomainError::UnknownError)
    .and_then(|is_valid| {
        if is_valid {
            Ok(user_account)
        } else {
            info!("Invalid password for user {}", user_account.email);
            Err(DomainError::InvalidCredentialsError)
        }
    })
}

pub fn from_db_user(user_account: DbUserAccount) -> User {
  User { id: user_account.id, email: user_account.email }
}
