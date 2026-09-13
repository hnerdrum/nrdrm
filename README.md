# nrdrm

Apps in this repo are independent. They share local Postgres via [`docker-databases.yml`](docker-databases.yml).

## Setup

1. Install [mise](https://mise.jdx.dev/).
2. From the repo root: `mise install`.
3. Haskell apps also need [Stack](https://docs.haskellstack.org/). GHC is not installed by mise; Stack pulls it from `server/recipes/stack.yaml`.
4. Start databases:

```bash
just db up
just env
```

`just --list` is the catalog. Every app answers `run`, `test`, `build`, and `migrate` (`just recipes run`, or `cd server/recipes && just run`). `just env` copies missing `.env` / `.env.local` from `.env.example` and will not overwrite.

| Host port | Database       | Used by                                                                                  |
| --------- | -------------- | ---------------------------------------------------------------------------------------- |
| 5432      | `recipes`      | [`server/recipes`](server/recipes)                                                       |
| 5433      | `identity`     | [`server/identity`](server/identity)                                                     |
| 5434      | `uno`          | [`server/uno`](server/uno)                                                               |
| 5435      | `recipes_test` | recipes tests only ([`docker-compose.test.yml`](server/recipes/docker-compose.test.yml)) |

## Apps

Each app README uses the same verbs: **run**, **test**, **build**, **migrate**.

CI runs those same commands on pull requests (`just recipes test`, `just identity build`, `just gateway test`). Scaleway deploy runs only after a green check on `main`.

### Backends

- [`server/recipes`](server/recipes) — Haskell recipe API
- [`server/identity`](server/identity) — Rust auth API
- [`server/gateway`](server/gateway) — Gleam reverse proxy
- [`server/uno`](server/uno) — Go Uno API (local only)

Shared Haskell libraries: [`server/orm`](server/orm), [`server/orm-codegen`](server/orm-codegen).

### Frontends

- [`web/recipes`](web/recipes) — Next.js, talks to the gateway
- [`web/uno`](web/uno) — SvelteKit, talks to the Uno API directly
- [`web/home`](web/home) — Astro landing page
- [`web/wedding`](web/wedding) — Astro wedding site

### Jobs

- [`cron/delete-container-images`](cron/delete-container-images) — Scaleway registry cleanup

## Recipes stack

The only multi-service path used daily. Start databases first, then one process per terminal:

```bash
just db up
just env
just identity run       # :8081 — runs Diesel migrations first
just recipes run        # :8000 — migrations on startup
just gateway run        # :8080
just web-recipes run    # :3000 → gateway
```
