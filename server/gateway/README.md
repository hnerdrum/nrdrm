# gateway

Gleam reverse proxy. No database. Routes `/<service>/...` using `services-dev.json` (local) or `services-prod.json` (`ENV=prod`).

## Run

```bash
just gateway run       # env bootstrap, then gleam run
```

Listens on `PORT` (default 8080). Local backends: recipes `:8000`, identity `:8081`, agents `:8090`. CORS: `ALLOWED_ORIGINS`.

`POST /agents/complete`, `POST /agents/runs`, and `GET /agents/runs/:id` require `Authorization: Bearer` with an identity access token whose audience is `agents`. The gateway asks identity to introspect that token, then calls agents without that token. Other agents paths, including `POST /agents/webhooks/github`, are forwarded without that check. Recipe writes still use the session cookie.

## Test

```bash
just gateway test
```

## Build

```bash
just gateway build
```

## Migrate

Not applicable.
