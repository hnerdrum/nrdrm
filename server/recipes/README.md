# recipes server

## Integration tests

ORM integration tests use a **dedicated test schema** (`test_widget` in `test/migrations/`) — not the application `ingredient` / `recipe` tables. The test database is separate from local dev data.

### Quick start

```bash
make test
```

This starts the test Postgres container, waits until it is healthy, and runs `stack test`.

### Commands

```bash
make help          # list all targets
make test          # start test DB + run tests
make test-fast     # run tests (DB must already be running)
make test-db-up    # start test DB only
make test-db-down  # stop test DB
make test-db-logs  # tail DB logs
```

### Environment

The default test database URL is defined in the `Makefile`. Override if needed:

```bash
make test TEST_DATABASE_URL=postgres://user:pass@127.0.0.1:5435/recipes_test
```

For `stack test` without Make, copy the example env file and start the DB first:

```bash
cp .env.test.example .env.test
make test-db-up
stack test
```

Use `make test` to start the database and run tests in one step.

### Connection refused?

The test database is not running. From `server/recipes/`:

```bash
make test-db-up   # start Postgres on port 5435
make test-fast    # then run tests
```

`Support.TestDb` loads `.env.test` first, then falls back to `.env`.

### Test layout

```
test/
  migrations/       # ORM-only schema (not app migrations/)
  Schema/Widget.hs  # test table instances for Insertable/Updatable/etc.
  ORM/              # ORM integration specs
  Support/          # harness + test migrations runner
```
