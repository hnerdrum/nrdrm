# agents

Effect HTTP service for the agent runner. No database in this phase.

## Run

```bash
just agents run
```

Listens on `PORT` (8090 in the example). `GET /health` returns `{ "status": "ok" }` and does not check a caller key. The process requires `AGENTS_API_KEY` and `SCALEWAY_API_KEY`, and does not start when either is missing or empty.

`POST /complete` and `POST /runs` require `Authorization: Bearer <AGENTS_API_KEY>`. A missing or wrong key returns 401 and does not call a model.

`POST /complete` takes `{ "model", "prompt" }`. `model` is `scaleway` or `openai`. The response is `{ "text", "provider", "modelId" }`. `scaleway` is `mistral-small-3.2-24b-instruct-2506` at `https://api.scaleway.ai/v1`. `openai` (`gpt-4.1-mini`) is available only when `OPENAI_API_KEY` is set.

`POST /runs` takes `{ "skill", "input" }` and an optional `model`. It loads `skills/<skill>.md` as the system prompt and runs that skill's tools. `model` defaults to `scaleway`. The response is `{ "text", "skill", "actor", "provider", "modelId" }`. `actor` is `agent:<skill>`. An unknown skill returns 404 and does not call a model. `skills/ping.md` has no tools and answers in one line.

```sh
curl -s localhost:8090/complete \
  -H "authorization: Bearer $AGENTS_API_KEY" \
  -H 'content-type: application/json' \
  -d '{"model":"scaleway","prompt":"Reply with one word: pong"}'

curl -s localhost:8090/runs \
  -H "authorization: Bearer $AGENTS_API_KEY" \
  -H 'content-type: application/json' \
  -d '{"skill":"ping","input":"Say pong"}'
```

## Test

No automated tests yet.

## Build

```bash
just agents build
```

## Migrate

No database.
