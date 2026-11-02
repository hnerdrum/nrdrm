use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use tracing::error;

use crate::{database::auth_token::AuthToken, domain::error::DomainError};

use super::model::{Auth, User};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JwtClaims {
    pub exp: usize, // Expiration time
    pub iat: usize, // Issued at time

    auth: Auth,
}

pub fn create_jwt_token(
    user: User,
    auth_token: AuthToken,
    secret: String,
) -> Result<String, DomainError> {
    let claims = JwtClaims {
        auth: Auth {
            user_id: user.id,
            email: user.email,
            token_id: auth_token.id,
        },
        exp: auth_token.expires_at.timestamp() as usize,
        iat: auth_token.issued_at.timestamp() as usize,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|err| {
        error!("Error when creating JWT token: {}", err);
        DomainError::UnknownError
    })
}

pub fn decode_jwt_token(token: &str, secret: String) -> Result<Auth, DomainError> {
    decode::<JwtClaims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )
    .map(|token_data| token_data.claims)
    .map(|claims| claims.auth)
    .map_err(|err| {
        error!("Error when decoding JWT token: {}", err);
        DomainError::UnknownError
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::auth_token::{AuthToken, TokenStatus};
    use chrono::{Duration, Utc};
    use uuid::Uuid;

    fn session() -> (User, AuthToken) {
        let now = Utc::now();
        let user_id = Uuid::new_v4();
        let user = User {
            id: user_id,
            email: "ada@example.com".into(),
        };
        let auth_token = AuthToken {
            id: Uuid::new_v4(),
            created_at: now,
            updated_at: now,
            status: TokenStatus::Normal,
            user_id,
            issued_at: now,
            expires_at: now + Duration::hours(1),
        };
        (user, auth_token)
    }

    #[test]
    fn round_trips_the_session() {
        let (user, auth_token) = session();
        let secret = "test-secret".to_string();
        let encoded = create_jwt_token(user.clone(), auth_token.clone(), secret.clone()).unwrap();
        let auth = decode_jwt_token(&encoded, secret).unwrap();
        assert_eq!(auth.user_id, user.id);
        assert_eq!(auth.email, user.email);
        assert_eq!(auth.token_id, auth_token.id);
    }

    #[test]
    fn rejects_a_different_secret() {
        let (user, auth_token) = session();
        let encoded = create_jwt_token(user, auth_token, "test-secret".into()).unwrap();
        let err = decode_jwt_token(&encoded, "other-secret".into()).unwrap_err();
        assert!(matches!(err, DomainError::UnknownError));
    }

    #[test]
    fn rejects_an_expired_token() {
        let (user, mut auth_token) = session();
        auth_token.expires_at = Utc::now() - Duration::hours(2);
        auth_token.issued_at = auth_token.expires_at - Duration::minutes(1);
        let encoded = create_jwt_token(user, auth_token, "test-secret".into()).unwrap();
        let err = decode_jwt_token(&encoded, "test-secret".into()).unwrap_err();
        assert!(matches!(err, DomainError::UnknownError));
    }
}
