use deadpool_diesel::postgres::{Manager, Pool};

pub fn create_connection_pool(database_url: String) -> Pool {
    let manager = Manager::new(database_url, deadpool_diesel::Runtime::Tokio1);
    Pool::builder(manager).build().unwrap()
}
