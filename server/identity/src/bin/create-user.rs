use bcrypt::hash;
use identity::config::load_config;
use identity::database::connection::create_connection_pool;
use identity::database::error::DatabaseError;
use identity::database::user_account::create_user;
use std::env;
use std::process::exit;

#[tokio::main]
async fn main() {
    let mut args = env::args().skip(1);
    let Some(email) = args.next() else {
        usage();
    };
    let Some(password) = args.next() else {
        usage();
    };
    if args.next().is_some() || email.is_empty() || password.is_empty() {
        usage();
    }

    let config = load_config();
    let pool = create_connection_pool(config.database_url);
    let password_hash = match hash(password, bcrypt::DEFAULT_COST) {
        Ok(hash) => hash,
        Err(err) => {
            eprintln!("could not hash password: {err}");
            exit(1);
        }
    };
    if let Err(err) = create_user(&pool, email.clone(), password_hash).await {
        match err {
            DatabaseError::AlreadyExists => eprintln!("user already exists"),
            err => eprintln!("could not create user: {err:?}"),
        }
        exit(1);
    }
    println!("created {email}");
}

fn usage() -> ! {
    eprintln!("usage: create-user <email> <password>");
    exit(1);
}
