use identity::database::connection::create_connection_pool;
use identity::database::error::DatabaseError;
use identity::domain::oauth::register_client;
use std::env;
use std::process::exit;

#[tokio::main]
async fn main() {
    let _ = dotenvy::dotenv();

    let mut args = env::args().skip(1);
    let Some(name) = args.next() else {
        usage();
    };
    let Some(audience) = args.next() else {
        usage();
    };
    if args.next().is_some() || name.is_empty() || audience.is_empty() {
        usage();
    }

    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let pool = create_connection_pool(database_url);

    match register_client(&pool, name, audience).await {
        Ok(client) => {
            println!("client_id={}", client.client_id);
            println!("client_secret={}", client.client_secret);
            eprintln!("Store the client secret now. It is not shown again.");
        }
        Err(DatabaseError::AlreadyExists) => {
            eprintln!("A client with that name already exists.");
            exit(1);
        }
        Err(err) => {
            eprintln!("Failed to create client: {err:?}");
            exit(1);
        }
    }
}

fn usage() -> ! {
    eprintln!("usage: create-client <name> <audience>");
    exit(1);
}
