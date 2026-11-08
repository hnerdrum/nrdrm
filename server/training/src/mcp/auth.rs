//! Who is calling the training log.
//!
//! Training does not check passwords. A [`TokenVerifier`] turns a bearer
//! token into an email, and the endpoint allows only the owner's email.

use async_trait::async_trait;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedCaller {
    pub email: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TokenError {
    Invalid,
    Unavailable,
}

#[async_trait]
pub trait TokenVerifier: Send + Sync {
    async fn verify(&self, token: &str) -> Result<VerifiedCaller, TokenError>;
}

/// Refuses every token.
///
/// The training log asks identity once identity can issue a token for a person.
#[derive(Debug, Clone, Copy)]
pub struct ClosedTokens;

#[async_trait]
impl TokenVerifier for ClosedTokens {
    async fn verify(&self, _token: &str) -> Result<VerifiedCaller, TokenError> {
        Err(TokenError::Invalid)
    }
}

#[cfg(test)]
#[derive(Debug, Clone, Copy)]
pub(crate) struct FakeTokens;

#[cfg(test)]
#[async_trait]
impl TokenVerifier for FakeTokens {
    async fn verify(&self, token: &str) -> Result<VerifiedCaller, TokenError> {
        match token {
            "owner" => Ok(VerifiedCaller {
                email: "ada@example.com".to_string(),
            }),
            "other" => Ok(VerifiedCaller {
                email: "other@example.com".to_string(),
            }),
            "down" => Err(TokenError::Unavailable),
            _ => Err(TokenError::Invalid),
        }
    }
}
