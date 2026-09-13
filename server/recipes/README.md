# recipes server

Haskell/Servant API. Dev Postgres is port **5432** (`recipes` in [`docker-databases.yml`](../../docker-databases.yml)).

## Run

From the repo root, start databases, then:

```bash
just db up
just recipes run
```

Listens on `PORT` (default 8000).

## Test

Integration tests use a dedicated test schema (`test/migrations/`), not the application tables, and a separate database on port **5435**.

```bash
just recipes test        # start test DB + run tests
just recipes test-fast   # tests only (DB must already be running)
just recipes             # all targets
```

CI sets `STACK_ARCH=x86_64`. Local default is `aarch64`.

Override the URL if needed:

```bash
just recipes test TEST_DATABASE_URL=postgres://user:pass@127.0.0.1:5435/recipes_test
```

For `stack test` without just:

```bash
cp .env.test.example .env.test
just recipes test-db-up
stack --arch=aarch64 test
```

`Support.TestDb` loads `.env.test` first, then falls back to `.env`. If you get connection refused, the test database is not running (`just recipes test-db-up`).

```
test/
  migrations/       # ORM-only schema (not app migrations/)
  Schema/Widget.hs  # test table instances
  ORM/              # ORM integration specs
  Support/          # harness + test migrations runner
```

## Build

```bash
just recipes build
```

Also regenerates ORM client code (`just recipes orm-gen`).

## Migrate

Hand-written SQL in `migrations/`. Applied automatically on process start. No separate CLI.

Schema vs live Postgres: `just recipes orm-schema-check` (uses the test DB on 5435).
