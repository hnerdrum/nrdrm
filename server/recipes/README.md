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

Domain unit tests. They do not need Postgres.

```bash
just recipes test        # generate Poppy clients, run tests
just recipes test-fast   # tests only (clients must already be generated)
just recipes             # all targets
```

CI sets `STACK_ARCH=x86_64`. Local default is `aarch64`.

For `stack test` without just:

```bash
just recipes orm-gen
stack --arch=aarch64 test --fast recipes:recipes-test
```

```
test/
  Domain/           # domain unit tests
```

## Build

```bash
just recipes build
```

Also regenerates Poppy client code (`just recipes orm-gen`).

## Migrate

Hand-written SQL in `migrations/`. Applied automatically on process start. No separate CLI.

Schema vs live Postgres: `just recipes orm-schema-check` (uses the test DB on 5435).
