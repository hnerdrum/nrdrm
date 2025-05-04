
#[derive(Debug)]
pub enum DatabaseError {
    NotFoundError,
    ConnectionError,
    UnknownError
}
