use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use tracing::error;

use crate::{database::auth_token::AuthToken, domain::error::DomainError};

use super::model::{Auth, User};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JwtClaims {
    pub exp: usize,  // Expiration time
    pub iat: usize,  // Issued at time

    auth: Auth
}

pub fn create_jwt_token(user: User, auth_token: AuthToken, secret: String) -> Result<String, DomainError> {
  let claims = JwtClaims {
      auth: Auth { user_id: user.id, email: user.email, token_id: auth_token.id },
      exp: auth_token.expires_at.timestamp() as usize,
      iat: auth_token.issued_at.timestamp() as usize,
  };

  encode(&Header::default(), &claims, &EncodingKey::from_secret(secret.as_bytes()))
    .map_err(|err| {
      error!("Error when creating JWT token: {}", err);
      DomainError::UnknownError
    })
}

pub fn decode_jwt_token(token: &str, secret: String) -> Result<Auth, DomainError> {
  decode::<JwtClaims>(token, &DecodingKey::from_secret(secret.as_bytes()), &Validation::default())
    .map(|token_data| token_data.claims)
    .map(|claims| claims.auth)
    .map_err(|err| {
      error!("Error when decoding JWT token: {}", err);
      DomainError::UnknownError
    })
}
