use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::{Duration, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tracing::{error, info};
use uuid::Uuid;

use crate::database::{
    access_token::{find_access_token_by_hash, insert_access_token, NewAccessToken},
    connection::DBClient,
    error::DatabaseError,
    oauth_client::{client_has_audience, find_client_by_id, insert_client},
    user_account::find_user_by_id,
};

use super::error::DomainError;

pub(crate) const ACCESS_TOKEN_TTL_SECONDS: i64 = 3600;

#[derive(Deserialize, Debug)]
pub struct TokenRequest {
    pub grant_type: String,
    pub client_id: String,
    pub client_secret: String,
    pub audience: String,
}

#[derive(Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub token_type: String,
    pub expires_in: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub refresh_token: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub scope: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct IntrospectRequest {
    pub token: String,
}

#[derive(Serialize)]
pub struct Introspection {
    pub active: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub client_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub client_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub aud: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub exp: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sub: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub scope: Option<String>,
}

pub struct RegisteredClient {
    pub client_id: Uuid,
    pub client_secret: String,
}

pub struct ClientCredentials {
    pub client_id: Uuid,
    pub client_secret: String,
    pub secret_hash: String,
}

pub fn new_client_credentials() -> ClientCredentials {
    let client_secret = format!("nrdrm_{}", random_token());
    ClientCredentials {
        client_id: Uuid::new_v4(),
        client_secret: client_secret.clone(),
        secret_hash: hash_credential(&client_secret),
    }
}

pub async fn issue_access_token(
    db: &DBClient,
    input: TokenRequest,
) -> Result<TokenResponse, DomainError> {
    if input.grant_type != "client_credentials" {
        info!("Rejected grant type {}", input.grant_type);
        return Err(DomainError::InvalidCredentialsError);
    }

    let client_id = Uuid::parse_str(&input.client_id).map_err(|_| {
        info!("Rejected client id that is not a uuid");
        DomainError::InvalidCredentialsError
    })?;

    let client = find_client_by_id(db, client_id)
        .await
        .map_err(|err| match err {
            DatabaseError::NotFoundError => {
                info!("Client {client_id} not found");
                DomainError::InvalidCredentialsError
            }
            err => {
                error!("Encountered unexpected database error: {:?}", err);
                DomainError::UnknownError
            }
        })?;

    let Some(stored_hash) = client.secret_hash.as_deref() else {
        info!("Client {client_id} has no secret");
        return Err(DomainError::InvalidCredentialsError);
    };
    if !constant_eq(stored_hash, &hash_credential(&input.client_secret)) {
        info!("Invalid secret for client {client_id}");
        return Err(DomainError::InvalidCredentialsError);
    }

    let allowed = client_has_audience(db, client_id, input.audience.clone())
        .await
        .map_err(|err| {
            error!("Encountered unexpected database error: {:?}", err);
            DomainError::UnknownError
        })?;
    if !allowed {
        info!(
            "Client {client_id} is not allowed audience {}",
            input.audience
        );
        return Err(DomainError::InvalidCredentialsError);
    }

    let access_token = random_token();
    let expires_at = Utc::now() + Duration::seconds(ACCESS_TOKEN_TTL_SECONDS);
    insert_access_token(
        db,
        NewAccessToken {
            token_hash: hash_credential(&access_token),
            client_id,
            audience: input.audience,
            expires_at,
            user_id: None,
            scope: None,
        },
    )
    .await
    .map_err(|err| {
        error!("Encountered unexpected database error: {:?}", err);
        DomainError::UnknownError
    })?;

    Ok(TokenResponse {
        access_token,
        token_type: "Bearer".to_string(),
        expires_in: ACCESS_TOKEN_TTL_SECONDS,
        refresh_token: None,
        scope: None,
    })
}

pub async fn introspect_access_token(
    db: &DBClient,
    input: IntrospectRequest,
) -> Result<Introspection, DomainError> {
    let token = find_access_token_by_hash(db, hash_credential(&input.token))
        .await
        .map_err(|err| match err {
            DatabaseError::NotFoundError => DomainError::InvalidCredentialsError,
            err => {
                error!("Encountered unexpected database error: {:?}", err);
                DomainError::UnknownError
            }
        });

    let token = match token {
        Ok(token) => token,
        Err(DomainError::InvalidCredentialsError) => return Ok(inactive()),
        Err(err) => return Err(err),
    };

    if token.revoked_at.is_some() || token.expires_at <= Utc::now() {
        return Ok(inactive());
    }

    let client = match find_client_by_id(db, token.client_id).await {
        Ok(client) => client,
        Err(DatabaseError::NotFoundError) => return Ok(inactive()),
        Err(err) => {
            error!("Encountered unexpected database error: {:?}", err);
            return Err(DomainError::UnknownError);
        }
    };

    let (sub, email, scope) = match token.user_id {
        None => (None, None, None),
        Some(user_id) => {
            let user = match find_user_by_id(db, user_id).await {
                Ok(user) => user,
                Err(DatabaseError::NotFoundError) => return Ok(inactive()),
                Err(err) => {
                    error!("Encountered unexpected database error: {:?}", err);
                    return Err(DomainError::UnknownError);
                }
            };
            (
                Some(user.id.to_string()),
                Some(user.email),
                token.scope.clone(),
            )
        }
    };

    Ok(Introspection {
        active: true,
        client_id: Some(token.client_id),
        client_name: Some(client.name),
        aud: Some(token.audience),
        exp: Some(token.expires_at.timestamp()),
        sub,
        email,
        scope,
    })
}

pub async fn register_client(
    db: &DBClient,
    name: String,
    audience: String,
) -> Result<RegisteredClient, DatabaseError> {
    let credentials = new_client_credentials();
    let client = insert_client(db, name, credentials.secret_hash, audience).await?;
    Ok(RegisteredClient {
        client_id: client.id,
        client_secret: credentials.client_secret,
    })
}

fn inactive() -> Introspection {
    Introspection {
        active: false,
        client_id: None,
        client_name: None,
        aud: None,
        exp: None,
        sub: None,
        email: None,
        scope: None,
    }
}

pub(crate) fn hash_credential(value: &str) -> String {
    let digest = Sha256::digest(value.as_bytes());
    URL_SAFE_NO_PAD.encode(digest)
}

pub(crate) fn constant_eq(stored: &str, presented: &str) -> bool {
    if stored.len() != presented.len() {
        return false;
    }
    let mut diff = 0u8;
    for (left, right) in stored.bytes().zip(presented.bytes()) {
        diff |= left ^ right;
    }
    diff == 0
}

pub(crate) fn random_token() -> String {
    let mut bytes = [0u8; 32];
    bytes[..16].copy_from_slice(Uuid::new_v4().as_bytes());
    bytes[16..].copy_from_slice(Uuid::new_v4().as_bytes());
    URL_SAFE_NO_PAD.encode(bytes)
}
