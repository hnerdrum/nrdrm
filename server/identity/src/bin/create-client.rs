use identity::domain::oauth::new_client_credentials;
use std::env;
use std::process::exit;

fn main() {
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

    let credentials = new_client_credentials();
    println!("name={name}");
    println!("audience={audience}");
    println!("client_id={}", credentials.client_id);
    println!("client_secret={}", credentials.client_secret);
    println!("secret_hash={}", credentials.secret_hash);
}

fn usage() -> ! {
    eprintln!("usage: create-client <name> <audience>");
    exit(1);
}
