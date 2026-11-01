# nrdrm

Personal monorepo. I use it to try things out. [`web/home`](web/home) is my website.

The apps are independent, except the recipes stack at the bottom, where the gateway, identity, the recipe API, and the UI run together. Local Postgres is shared via [`docker-databases.yml`](docker-databases.yml).

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

| Host port | Database       | Used by                                                                                                                 |
| --------- | -------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 5432      | `recipes`      | [`server/recipes`](server/recipes)                                                                                      |
| 5433      | `identity`     | [`server/identity`](server/identity)                                                                                    |
| 5435      | `recipes_test` | recipes schema check (`just recipes schema-check`, [`docker-compose.test.yml`](server/recipes/docker-compose.test.yml)) |
| 5436      | `agents`       | [`server/agents`](server/agents)                                                                                        |

## Apps

### Backends

- [`server/recipes`](server/recipes) — Haskell recipe API (uses [Poppy](https://github.com/hnerdrum/poppy) for Postgres)
- [`server/identity`](server/identity) — Rust auth API
- [`server/gateway`](server/gateway) — Gleam reverse proxy
- [`server/agents`](server/agents) — TypeScript agent runner

### Frontends

- [`web/recipes`](web/recipes) — Next.js, talks to the gateway
- [`web/home`](web/home) — Astro landing page

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
