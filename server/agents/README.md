# agents

Effect HTTP service for the agent runner. No database in this phase.

## Run

```bash
just agents run
```

Listens on `PORT` (8090 in the example). `GET /health` returns `{ "status": "ok" }`.

## Test

No automated tests yet.

## Build

```bash
just agents build
```

## Migrate

No database.
