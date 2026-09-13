# gateway

Gleam reverse proxy. No database. Routes `/<service>/...` using `services-dev.json` (local) or `services-prod.json` (`ENV=prod`).

## Run

```bash
just gateway run       # env bootstrap, then gleam run
```

Listens on `PORT` (default 8080). Local backends: recipes `:8000`, identity `:8081`. CORS: `ALLOWED_ORIGINS`.

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
