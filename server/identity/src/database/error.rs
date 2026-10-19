#[derive(Debug)]
pub enum DatabaseError {
    NotFoundError,
    AlreadyExists,
    ConnectionError,
    UnknownError,
}

impl DatabaseError {
    pub fn from_diesel(err: diesel::result::Error) -> Self {
        match err {
            diesel::result::Error::NotFound => DatabaseError::NotFoundError,
            diesel::result::Error::DatabaseError(
                diesel::result::DatabaseErrorKind::UniqueViolation,
                _,
            ) => DatabaseError::AlreadyExists,
            _ => DatabaseError::UnknownError,
        }
    }
}
