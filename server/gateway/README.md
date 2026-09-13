# gateway

Gleam reverse proxy. No database. Routes `/<service>/...` using `services-dev.json` (local) or `services-prod.json` (`ENV=prod`).

## Run

```bash
cd server/gateway
cp .env.example .env   # if you do not already have one
gleam run
```

Listens on `PORT` (default 8080). Local backends: recipes `:8000`, identity `:8081`. CORS: `ALLOWED_ORIGINS`.

## Test

```bash
gleam test
```

## Build

```bash
gleam build
```

## Migrate

Not applicable.
