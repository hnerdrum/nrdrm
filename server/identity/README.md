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

`POST /api/v1/oauth/token` still accepts the agents JSON client-credentials grant: `{ "grant_type": "client_credentials", "client_id", "client_secret", "audience" }`. A valid client receives a one-hour bearer token.

The same path accepts a form body for a training agent. `grant_type=authorization_code` exchanges a code, PKCE verifier, redirect, and resource for an access token and a rotating refresh token. `grant_type=refresh_token` issues a new pair and retires the presented refresh token. Presenting a retired refresh token revokes that token's family. User access tokens last one hour. Refresh tokens last 30 days, and each rotation starts a new 30 days.

`GET /api/v1/oauth-authorization-server/identity` publishes the authorization-server metadata. Set `OAUTH_ISSUER` to the public identity URL, such as `http://localhost:8080/identity`.

`POST /api/v1/oauth/introspect` takes JSON `{ "token" }`. It returns whether the token is active, plus the client id, client name, and audience when it is. A user token also includes `sub`, `email`, and `scope`. Password login is unchanged.

```bash
just identity create-client agents-caller agents
```

That prints `name`, `audience`, `client_id`, `client_secret`, and `secret_hash`. It does not write to the database. Store the secret. Insert `secret_hash`, not the secret.

## Local test user

```bash
just identity seed
```

Migrates, then adds `test@test.com` with password `test`. Running it again changes nothing. It refuses to run when `ENV=prod` or when `DATABASE_URL` is not on `localhost`.

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
