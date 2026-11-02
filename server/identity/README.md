# identity

Rust/Axum auth API. Dev Postgres is port **5433** (`identity` in [`docker-databases.yml`](../../docker-databases.yml)).

Needs [diesel_cli](https://diesel.rs/guides/getting-started) with Postgres:

```bash
cargo install diesel_cli --version 2.2.12 --locked --no-default-features --features postgres
```

## Run

```bash
just db up
just identity run      # env bootstrap, Diesel migrations, then cargo run
```

Listens on `APP_PORT` (default 8081 locally).

`POST /api/v1/oauth/token` takes JSON `{ "grant_type": "client_credentials", "client_id", "client_secret", "audience" }`. A valid client receives a one-hour bearer token. `POST /api/v1/oauth/introspect` takes JSON `{ "token" }` and returns whether it is active, plus the client id, client name, and audience when it is. Password login is unchanged.

```bash
just identity create-client agents-caller agents
```

That prints `name`, `audience`, `client_id`, `client_secret`, and `secret_hash`. It does not write to the database. Store the secret. Insert `secret_hash`, not the secret.

## Test

```bash
just identity test
```

## Build

```bash
just identity build
```

## Migrate

Diesel, in `migrations/`. `just identity run` applies them before `cargo run` (same as the Docker entrypoint). Standalone:

```bash
just identity migrate
```
