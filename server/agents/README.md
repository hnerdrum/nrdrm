# agents

Effect HTTP service for the agent runner. Runs are stored in Postgres database `agents` on port `5436` (`just db up`).

## Run

```bash
just agents run
```

Listens on `PORT` (8090 in the example). `GET /health` returns `{ "status": "ok" }` and does not check a caller key. The process requires `AGENTS_API_KEY`, `SCALEWAY_API_KEY`, and `DATABASE_URL`, and does not start when any of them is missing or empty.

`POST /complete` and `POST /runs` require `Authorization: Bearer <AGENTS_API_KEY>`. A missing or wrong key returns 401 and does not call a model.

`POST /complete` takes `{ "model", "prompt" }`. `model` is `scaleway` or `openai`. The response is `{ "text", "provider", "modelId" }`. `scaleway` is `mistral-small-3.2-24b-instruct-2506` at `https://api.scaleway.ai/v1`. `openai` (`gpt-4.1-mini`) is available only when `OPENAI_API_KEY` is set.

`POST /runs` takes `{ "skill", "input", "model" }`. `model` is `scaleway` or `openai`. It loads `skills/<skill>.md` as the system prompt and runs that skill's tools. The response is `{ "id", "text", "skill", "actor", "provider", "modelId" }`. `actor` is `agent:<skill>`. A finished run is stored with that id, the model id, token counts, and start and finish times. An unknown skill returns 404 and does not call a model. `skills/ping.md` has no tools and answers in one line.

`GET /runs/:id` requires the same caller key and returns that row: `{ "id", "skill", "actor", "status", "modelId", "inputTokens", "outputTokens", "startedAt", "finishedAt" }`. A missing id returns 404.

```sh
curl -s localhost:8090/complete \
  -H "authorization: Bearer $AGENTS_API_KEY" \
  -H 'content-type: application/json' \
  -d '{"model":"scaleway","prompt":"Reply with one word: pong"}'

curl -s localhost:8090/runs \
  -H "authorization: Bearer $AGENTS_API_KEY" \
  -H 'content-type: application/json' \
  -d '{"skill":"ping","input":"Say pong","model":"scaleway"}'
```

## Test

No automated tests yet.

## Build

```bash
just agents build
```

## Migrate

```bash
just agents migrate
```

Applies the Drizzle migrations in `drizzle/`. `just agents run` does this first. `DATABASE_URL` comes from `.env`. The example points at the local agents database.
