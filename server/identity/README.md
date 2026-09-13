# identity

Rust/Axum auth API. Dev Postgres is port **5433** (`identity` in [`docker-databases.yml`](../../docker-databases.yml)).

Needs [diesel_cli](https://diesel.rs/guides/getting-started) with Postgres:

```bash
cargo install diesel_cli --no-default-features --features postgres
```

## Run

```bash
cd server/identity
cp .env.example .env   # if you do not already have one
diesel migration run
cargo run
```

Listens on `APP_PORT` (default 8081 locally).

## Test

No automated tests yet.

## Build

```bash
cargo build
```

## Migrate

Diesel, in `migrations/`. Not run by `cargo run` — apply them first:

```bash
diesel migration run
```

The Docker image runs this in its entrypoint.
