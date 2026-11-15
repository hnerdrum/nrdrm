use std::collections::HashMap;

use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::{Duration, Utc};
use serde::Serialize;
use sha2::{Digest, Sha256};
use tracing::{error, info};
use uuid::Uuid;

use crate::database::{
    access_token::NewAccessToken,
    authorization_code::{consume_authorization_code, ConsumedCode},
    connection::DBClient,
    error::DatabaseError,
    oauth_client::{find_client_by_id, OauthClient},
    refresh_token::{
        find_refresh_token_by_hash, insert_token_pair, revoke_refresh_family, rotate_refresh_token,
        NewRefreshToken, Rotation,
    },
};

use super::{
    error::DomainError,
    oauth::{
        constant_eq, hash_credential, issue_access_token, random_token, TokenRequest,
        TokenResponse, ACCESS_TOKEN_TTL_SECONDS,
    },
};

const REFRESH_TOKEN_TTL_DAYS: i64 = 30;

#[derive(Debug)]
pub enum TokenError {
    InvalidRequest,
    InvalidClient,
    InvalidGrant,
    UnsupportedGrant,
    Unavailable,
}

#[derive(Serialize)]
pub struct AuthorizationServerMetadata {
    pub issuer: String,
    pub authorization_endpoint: String,
    pub token_endpoint: String,
    pub registration_endpoint: String,
    pub scopes_supported: Vec<String>,
    pub response_types_supported: Vec<String>,
    pub grant_types_supported: Vec<String>,
    pub code_challenge_methods_supported: Vec<String>,
    pub token_endpoint_auth_methods_supported: Vec<String>,
}

pub fn authorization_server_metadata(issuer: &str) -> Result<AuthorizationServerMetadata, ()> {
    let issuer = issuer.trim().trim_end_matches('/').to_string();
    if issuer.is_empty() {
        return Err(());
    }
    Ok(AuthorizationServerMetadata {
        authorization_endpoint: format!("{issuer}/oauth/authorize"),
        token_endpoint: format!("{issuer}/oauth/token"),
        registration_endpoint: format!("{issuer}/oauth/register"),
        scopes_supported: vec!["training".to_string()],
        response_types_supported: vec!["code".to_string()],
        grant_types_supported: vec![
            "authorization_code".to_string(),
            "refresh_token".to_string(),
            "client_credentials".to_string(),
        ],
        code_challenge_methods_supported: vec!["S256".to_string()],
        token_endpoint_auth_methods_supported: vec![
            "none".to_string(),
            "client_secret_post".to_string(),
        ],
        issuer,
    })
}

pub async fn exchange_form(
    db: &DBClient,
    fields: &HashMap<String, String>,
) -> Result<TokenResponse, TokenError> {
    let grant_type = require(fields, "grant_type")?;
    match grant_type.as_str() {
        "authorization_code" => exchange_authorization_code(db, fields).await,
        "refresh_token" => exchange_refresh_token(db, fields).await,
        "client_credentials" => exchange_client_credentials(db, fields).await,
        _ => {
            info!("Rejected grant type");
            Err(TokenError::UnsupportedGrant)
        }
    }
}

pub(crate) fn pkce_s256(verifier: &str) -> Option<String> {
    if !(43..=128).contains(&verifier.len()) {
        return None;
    }
    if !verifier
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '.' | '_' | '~'))
    {
        return None;
    }
    let digest = Sha256::digest(verifier.as_bytes());
    Some(URL_SAFE_NO_PAD.encode(digest))
}

async fn exchange_client_credentials(
    db: &DBClient,
    fields: &HashMap<String, String>,
) -> Result<TokenResponse, TokenError> {
    let request = TokenRequest {
        grant_type: "client_credentials".to_string(),
        client_id: require(fields, "client_id")?,
        client_secret: require(fields, "client_secret")?,
        audience: require(fields, "audience")?,
    };
    match issue_access_token(db, request).await {
        Ok(token) => Ok(token),
        Err(DomainError::InvalidCredentialsError) => Err(TokenError::InvalidClient),
        Err(DomainError::UnknownError) => Err(TokenError::Unavailable),
    }
}

async fn exchange_authorization_code(
    db: &DBClient,
    fields: &HashMap<String, String>,
) -> Result<TokenResponse, TokenError> {
    let code = require(fields, "code")?;
    let redirect_uri = require(fields, "redirect_uri")?;
    let client_id = parse_client_id(&require(fields, "client_id")?)?;
    let verifier = require(fields, "code_verifier")?;
    let resource = require(fields, "resource")?;
    let secret = field(fields, "client_secret");

    // The code is single use, including when the verifier or redirect is wrong.
    let code = match consume_authorization_code(db, hash_credential(&code)).await {
        Ok(ConsumedCode::Fresh(code)) => code,
        Ok(ConsumedCode::AlreadyUsed) => {
            info!("Authorization code reuse");
            return Err(TokenError::InvalidGrant);
        }
        Ok(ConsumedCode::Unknown) => {
            info!("Authorization code not found");
            return Err(TokenError::InvalidGrant);
        }
        Err(err) => return Err(unavailable(err)),
    };

    if code.client_id != client_id {
        info!("Authorization code presented for a different client");
        return Err(TokenError::InvalidGrant);
    }
    if code.redirect_uri != redirect_uri {
        info!("Authorization code presented with a different redirect");
        return Err(TokenError::InvalidGrant);
    }
    if code.resource != resource {
        info!("Authorization code presented for a different resource");
        return Err(TokenError::InvalidGrant);
    }
    if code.expires_at <= Utc::now() {
        info!("Authorization code expired");
        return Err(TokenError::InvalidGrant);
    }
    if !verifier_matches(&code.code_challenge, &verifier) {
        info!("PKCE verification failed");
        return Err(TokenError::InvalidGrant);
    }

    let client = load_client(db, client_id).await?;
    authenticate_client(&client, secret.as_deref())?;

    let issued = issue_pair(
        db,
        client_id,
        code.user_id,
        code.resource,
        code.scope,
        Uuid::new_v4(),
    )
    .await?;
    Ok(user_token(issued))
}

async fn exchange_refresh_token(
    db: &DBClient,
    fields: &HashMap<String, String>,
) -> Result<TokenResponse, TokenError> {
    let presented = require(fields, "refresh_token")?;
    let client_id = parse_client_id(&require(fields, "client_id")?)?;
    let resource = require(fields, "resource")?;
    let secret = field(fields, "client_secret");

    let token = match find_refresh_token_by_hash(db, hash_credential(&presented)).await {
        Ok(token) => token,
        Err(DatabaseError::NotFoundError) => {
            info!("Refresh token not found");
            return Err(TokenError::InvalidGrant);
        }
        Err(err) => return Err(unavailable(err)),
    };

    if token.client_id != client_id {
        info!("Refresh token presented for a different client");
        return Err(TokenError::InvalidGrant);
    }
    if token.resource != resource {
        info!("Refresh token presented for a different resource");
        return Err(TokenError::InvalidGrant);
    }
    if token.revoked_at.is_some() || token.replaced_by.is_some() {
        info!("Refresh token reuse for family {}", token.family_id);
        revoke_refresh_family(db, token.family_id)
            .await
            .map_err(unavailable)?;
        return Err(TokenError::InvalidGrant);
    }
    if token.expires_at <= Utc::now() {
        info!("Refresh token expired");
        return Err(TokenError::InvalidGrant);
    }

    let client = load_client(db, client_id).await?;
    authenticate_client(&client, secret.as_deref())?;

    let access_token = random_token();
    let refresh_token = random_token();
    let now = Utc::now();
    let scope = token.scope.clone();
    let rotation = rotate_refresh_token(
        db,
        token.id,
        NewAccessToken {
            token_hash: hash_credential(&access_token),
            client_id,
            audience: token.resource.clone(),
            expires_at: now + Duration::seconds(ACCESS_TOKEN_TTL_SECONDS),
            user_id: Some(token.user_id),
            scope: Some(scope.clone()),
        },
        NewRefreshToken {
            token_hash: hash_credential(&refresh_token),
            client_id,
            user_id: token.user_id,
            resource: token.resource,
            scope: scope.clone(),
            family_id: token.family_id,
            expires_at: now + Duration::days(REFRESH_TOKEN_TTL_DAYS),
        },
    )
    .await
    .map_err(unavailable)?;

    if matches!(rotation, Rotation::LostRace) {
        info!("Refresh token reuse for family {}", token.family_id);
        revoke_refresh_family(db, token.family_id)
            .await
            .map_err(unavailable)?;
        return Err(TokenError::InvalidGrant);
    }

    Ok(user_token(Issued {
        access_token,
        refresh_token,
        scope,
    }))
}

struct Issued {
    access_token: String,
    refresh_token: String,
    scope: String,
}

async fn issue_pair(
    db: &DBClient,
    client_id: Uuid,
    user_id: Uuid,
    resource: String,
    scope: String,
    family_id: Uuid,
) -> Result<Issued, TokenError> {
    let access_token = random_token();
    let refresh_token = random_token();
    let now = Utc::now();
    insert_token_pair(
        db,
        NewAccessToken {
            token_hash: hash_credential(&access_token),
            client_id,
            audience: resource.clone(),
            expires_at: now + Duration::seconds(ACCESS_TOKEN_TTL_SECONDS),
            user_id: Some(user_id),
            scope: Some(scope.clone()),
        },
        NewRefreshToken {
            token_hash: hash_credential(&refresh_token),
            client_id,
            user_id,
            resource,
            scope: scope.clone(),
            family_id,
            expires_at: now + Duration::days(REFRESH_TOKEN_TTL_DAYS),
        },
    )
    .await
    .map_err(unavailable)?;
    Ok(Issued {
        access_token,
        refresh_token,
        scope,
    })
}

fn user_token(issued: Issued) -> TokenResponse {
    TokenResponse {
        access_token: issued.access_token,
        token_type: "Bearer".to_string(),
        expires_in: ACCESS_TOKEN_TTL_SECONDS,
        refresh_token: Some(issued.refresh_token),
        scope: Some(issued.scope),
    }
}

async fn load_client(db: &DBClient, client_id: Uuid) -> Result<OauthClient, TokenError> {
    match find_client_by_id(db, client_id).await {
        Ok(client) => Ok(client),
        Err(DatabaseError::NotFoundError) => {
            info!("Client {client_id} not found");
            Err(TokenError::InvalidGrant)
        }
        Err(err) => Err(unavailable(err)),
    }
}

fn authenticate_client(client: &OauthClient, secret: Option<&str>) -> Result<(), TokenError> {
    let Some(stored) = client.secret_hash.as_deref() else {
        return Ok(());
    };
    let Some(secret) = secret.filter(|secret| !secret.is_empty()) else {
        info!("Confidential client {} presented no secret", client.id);
        return Err(TokenError::InvalidClient);
    };
    if constant_eq(stored, &hash_credential(secret)) {
        Ok(())
    } else {
        info!("Invalid secret for client {}", client.id);
        Err(TokenError::InvalidClient)
    }
}

fn verifier_matches(challenge: &str, verifier: &str) -> bool {
    let Some(computed) = pkce_s256(verifier) else {
        return false;
    };
    constant_eq(challenge, &computed)
}

fn parse_client_id(raw: &str) -> Result<Uuid, TokenError> {
    Uuid::parse_str(raw).map_err(|_| {
        info!("Rejected client id that is not a uuid");
        TokenError::InvalidGrant
    })
}

fn require(fields: &HashMap<String, String>, key: &str) -> Result<String, TokenError> {
    field(fields, key).ok_or(TokenError::InvalidRequest)
}

fn field(fields: &HashMap<String, String>, key: &str) -> Option<String> {
    fields
        .get(key)
        .map(String::as_str)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

fn unavailable(err: DatabaseError) -> TokenError {
    error!("Encountered unexpected database error: {:?}", err);
    TokenError::Unavailable
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pkce_matches_the_s256_vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
        assert_eq!(
            pkce_s256(verifier).as_deref(),
            Some("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        );
        assert!(pkce_s256("short").is_none());
        assert!(pkce_s256("has a space and is long enough to pass the length").is_none());
    }

    #[test]
    fn metadata_uses_the_issuer_as_the_base() {
        let metadata = authorization_server_metadata("http://localhost:8080/identity/").unwrap();
        assert_eq!(metadata.issuer, "http://localhost:8080/identity");
        assert_eq!(
            metadata.authorization_endpoint,
            "http://localhost:8080/identity/oauth/authorize"
        );
        assert_eq!(
            metadata.token_endpoint,
            "http://localhost:8080/identity/oauth/token"
        );
        assert_eq!(
            metadata.registration_endpoint,
            "http://localhost:8080/identity/oauth/register"
        );
        assert_eq!(metadata.scopes_supported, vec!["training"]);
        assert_eq!(metadata.response_types_supported, vec!["code"]);
        assert_eq!(
            metadata.grant_types_supported,
            vec!["authorization_code", "refresh_token", "client_credentials"]
        );
        assert_eq!(metadata.code_challenge_methods_supported, vec!["S256"]);
        assert_eq!(
            metadata.token_endpoint_auth_methods_supported,
            vec!["none", "client_secret_post"]
        );
    }

    #[test]
    fn metadata_requires_an_issuer() {
        assert!(authorization_server_metadata("  ").is_err());
    }
}
