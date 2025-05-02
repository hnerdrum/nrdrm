use bcrypt::verify;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use crate::database::user_account::{find_user_by_email, DbUserAccount};
use crate::database::connection::DBClient;

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

#[derive(Serialize, Clone)]
pub struct Auth {
  pub user_id: Uuid,
  pub email: String
}

#[derive(Deserialize, Debug)]
pub struct LoginInput {
  email: String,
  password: String,
}

#[derive(Debug)]
pub enum LoginError {
    InvalidCredentialsError,
    UnknownError
}

pub async fn login_user(db: DBClient, input: LoginInput) -> Result<User, LoginError> {
  let user_account = find_user_by_email(&db, input.email)
  .await
  .map_err(|_| LoginError::InvalidCredentialsError)?;

  verify_user_password(user_account, input.password)
    .map(|user| from_db_user(user))
}

fn verify_user_password(user_account: DbUserAccount, password: String) -> Result<DbUserAccount, LoginError> {
  verify(password, &user_account.password_hash)
    .map_err(|_| LoginError::UnknownError)
    .and_then(|is_valid| {
        if is_valid {
            Ok(user_account)
        } else {
            Err(LoginError::InvalidCredentialsError)
        }
    })
}

pub fn from_db_user(user_account: DbUserAccount) -> User {
  User { id: user_account.id, email: user_account.email }
}

pub fn from_db_user_account(user_account: DbUserAccount) -> UserSettings {
  UserSettings { auth: Some(Auth { user_id: user_account.id, email: user_account.email }) }
}