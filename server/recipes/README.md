# recipes server

Haskell/Servant API. Dev Postgres is port **5432** (`recipes` in [`docker-databases.yml`](../../docker-databases.yml)).

## Run

From the repo root, start databases, then:

```bash
cd server/recipes
cp .env.example .env   # if you do not already have one
make run               # build + start; applies migrations on startup
```

Listens on `PORT` (default 8000).

## Test

Integration tests use a dedicated test schema (`test/migrations/`), not the application tables, and a separate database on port **5435**.

```bash
make test              # start test DB + run tests
make test-fast         # tests only (DB must already be running)
make help              # all targets
```

Override the URL if needed:

```bash
make test TEST_DATABASE_URL=postgres://user:pass@127.0.0.1:5435/recipes_test
```

For `stack test` without Make:

```bash
cp .env.test.example .env.test
make test-db-up
stack test
```

`Support.TestDb` loads `.env.test` first, then falls back to `.env`. If you get connection refused, the test database is not running (`make test-db-up`).

```
test/
  migrations/       # ORM-only schema (not app migrations/)
  Schema/Widget.hs  # test table instances
  ORM/              # ORM integration specs
  Support/          # harness + test migrations runner
```

## Build

```bash
make build
```

Also regenerates ORM client code (`make orm-gen`).

## Migrate

Hand-written SQL in `migrations/`. Applied automatically on process start. No separate CLI.

Schema vs live Postgres: `make orm-schema-check` (uses the test DB on 5435).
