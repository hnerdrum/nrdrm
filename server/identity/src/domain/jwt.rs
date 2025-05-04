use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use tracing::error;

use crate::domain::error::DomainError;

use super::model::Auth;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JwtClaims {
    pub exp: usize,  // Expiration time
    pub iat: usize,  // Issued at time

    auth: Auth
}

pub fn create_jwt_token(auth: Auth, secret: String) -> Result<String, DomainError> {
  let now = Utc::now();
  let claims = JwtClaims {
      auth,
      exp: (now + Duration::hours(24)).timestamp() as usize, // TODO: get from auth token
      iat: now.timestamp() as usize,
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
