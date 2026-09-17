# recipes server

Haskell/Servant API. Dev Postgres is port **5432** (`recipes` in [`docker-databases.yml`](../../docker-databases.yml)). Persistence uses [Poppy](https://github.com/hnerdrum/poppy): this app owns the Schema and generated Client.

## Run

From the repo root, start databases, then:

```bash
just db up
just recipes run
```

Listens on `PORT` (default 8000).

## Test

Integration tests use the application schema (after migrations) and a separate database on port **5435**.

```bash
just recipes test        # start test DB, generate Poppy clients, run tests
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
just recipes orm-gen
stack --arch=aarch64 test --fast recipes:recipes-test
```

`Support.TestDb` loads `.env.test` first, then falls back to `.env`. If you get connection refused, the test database is not running (`just recipes test-db-up`).

```
test/
  Domain/           # domain unit tests
  ORM/              # generated-Client integration specs
  Support/          # harness
```

## Build

```bash
just recipes build
```

Also regenerates Poppy client code (`just recipes orm-gen`).

## Migrate

Hand-written SQL in `migrations/`. Applied automatically on process start. No separate CLI.

Schema vs live Postgres: `just recipes orm-schema-check` (uses the test DB on 5435).
