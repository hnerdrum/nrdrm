# gateway

Gleam reverse proxy. No database. Routes `/<service>/...` using `services-dev.json` (local) or `services-prod.json` (`ENV=prod`).

## Run

```bash
just gateway run       # env bootstrap, then gleam run
```

Listens on `PORT` (default 8080). Local backends: recipes `:8000`, identity `:8081`, agents `:8090`. CORS: `ALLOWED_ORIGINS`.

`POST /agents/complete`, `POST /agents/runs`, and `GET /agents/runs/:id` require `Authorization: Bearer` with an identity access token whose audience is `agents`. The gateway asks identity to introspect that token, then calls agents without that token. Other agents paths, including `POST /agents/webhooks/github`, are forwarded without that check. Recipe writes still use the session cookie.

An auth rule's `path` is matched segment by segment against the path after `/<service>`: a literal segment matches itself, `*` matches exactly one segment, and `**` (last segment only) matches any remaining segments, including none. Path patterns, methods, and base URLs are checked when the gateway boots, and a bad entry stops it from starting.

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
