use deadpool_diesel::postgres::{Manager, Pool};
use deadpool_diesel::{ManagerConfig, RecyclingMethod};

pub fn create_connection_pool(database_url: String) -> Pool {
    // Fast never pings, so a connection the server closed while it sat idle is
    // handed out and the first query fails.
    let manager = Manager::from_config(
        database_url,
        deadpool_diesel::Runtime::Tokio1,
        ManagerConfig {
            recycling_method: RecyclingMethod::Verified,
        },
    );
    Pool::builder(manager).build().unwrap()
}

#[cfg(test)]
mod tests {
    use diesel::prelude::*;
    use diesel::sql_types::Integer;

    use super::*;

    #[derive(QueryableByName)]
    struct BackendPid {
        #[diesel(sql_type = Integer)]
        pid: i32,
    }

    #[tokio::test]
    async fn a_connection_closed_by_the_server_is_replaced() {
        let url = "postgres://nrdrm:nrdrm@localhost:5437/training";
        let pool = create_connection_pool(url.to_string());
        let held = pool.get().await.expect("checkout");
        let pid = held
            .interact(|conn| {
                diesel::sql_query("SELECT pg_backend_pid() AS pid").get_result::<BackendPid>(conn)
            })
            .await
            .expect("pid task")
            .expect("pid")
            .pid;
        drop(held);

        let mut admin = PgConnection::establish(url).expect("admin connection");
        diesel::sql_query(format!("SELECT pg_terminate_backend({pid})"))
            .execute(&mut admin)
            .expect("terminate");

        let replacement = pool.get().await.expect("replacement");
        replacement
            .interact(|conn| diesel::sql_query("SELECT 1").execute(conn))
            .await
            .expect("query task")
            .expect("live connection");
    }
}
