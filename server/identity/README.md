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

## Test

No automated tests yet.

## Build

```bash
just identity build
```

## Migrate

Diesel, in `migrations/`. `just identity run` applies them before `cargo run` (same as the Docker entrypoint). Standalone:

```bash
just identity migrate
```
