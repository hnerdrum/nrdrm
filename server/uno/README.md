# uno

Go/Gin API for the Uno frontend. Dev Postgres is port **5434** (`uno` in [`docker-databases.yml`](../../docker-databases.yml)). Local only — not behind the gateway.

## Run

```bash
just db up
cp .env.example .env   # required; the process exits without it
just uno run           # or: cd server/uno && just run
```

Listens on `PORT` (8082 in the example, matching [`web/uno`](../../web/uno)).

## Test

No automated tests yet.

## Build

```bash
just uno build
```

## Migrate

GORM `AutoMigrate` on startup. No SQL migration files.
