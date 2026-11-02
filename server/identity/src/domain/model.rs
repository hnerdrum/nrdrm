use crate::database::connection::DBClient;
use crate::database::error::DatabaseError;
use crate::database::user_account::{find_user_by_email, UserAccount};
use bcrypt::verify;
use serde::{Deserialize, Serialize};
use tracing::{error, info};
use uuid::Uuid;

use super::error::DomainError;

#[derive(Serialize)]
pub struct HealthCheck {
    pub boot_time: String,
    pub api_version: String,
}

#[derive(Serialize)]
pub struct TokenValidation {
    pub valid: bool,
}

#[derive(Serialize)]
pub struct UserSettings {
    pub auth: Option<Auth>,
}

#[derive(Serialize, Clone)]
pub struct User {
    pub id: Uuid,
    pub email: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Auth {
    pub user_id: Uuid,
    pub token_id: Uuid,
    pub email: String,
}

#[derive(Deserialize, Debug)]
pub struct LoginInput {
    email: String,
    password: String,
}

pub async fn login_user(db: DBClient, input: LoginInput) -> Result<User, DomainError> {
    let user_account =
        find_user_by_email(&db, input.email.clone())
            .await
            .map_err(|err| match err {
                DatabaseError::NotFoundError => {
                    info!("User not found for email {}", input.email.clone());
                    DomainError::InvalidCredentialsError
                }
                err => {
                    error!("Encountered unexpected database error: {:?}", err);
                    DomainError::UnknownError
                }
            })?;

    verify_user_password(user_account, input.password).map(|user| from_db_user(user))
}

fn verify_user_password(
    user_account: UserAccount,
    password: String,
) -> Result<UserAccount, DomainError> {
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

#[cfg(test)]
mod tests {
    use super::*;
    use bcrypt::hash;
    use chrono::Utc;

    fn account(password_hash: &str) -> UserAccount {
        let now = Utc::now();
        UserAccount {
            id: Uuid::new_v4(),
            created_at: now,
            updated_at: now,
            email: "ada@example.com".into(),
            password_hash: password_hash.into(),
        }
    }

    #[test]
    fn accepts_the_password_that_was_hashed() {
        let password = "correct horse";
        let hashed = hash(password, 4).unwrap();
        assert!(verify_user_password(account(&hashed), password.into()).is_ok());
    }

    #[test]
    fn rejects_a_different_password() {
        let hashed = hash("correct horse", 4).unwrap();
        let err = verify_user_password(account(&hashed), "nope".into()).unwrap_err();
        assert!(matches!(err, DomainError::InvalidCredentialsError));
    }
}

pub fn from_db_user(user_account: UserAccount) -> User {
    User {
        id: user_account.id,
        email: user_account.email,
    }
}
