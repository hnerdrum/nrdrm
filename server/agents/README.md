# agents

Effect HTTP service for the agent runner. No database in this phase.

## Run

```bash
just agents run
```

Listens on `PORT` (8090 in the example). `GET /health` returns `{ "status": "ok" }`. The process requires `SCALEWAY_API_KEY` and does not start when that key is missing or empty.

`POST /complete` sends a prompt to a named model and returns `{ "text", "model", "modelId" }`. The default name is `scaleway` (`mistral-small-3.2-24b-instruct-2506` at `https://api.scaleway.ai/v1`). An unknown name returns 400 and does not call a provider. `openai` (`gpt-4.1-mini`) is available only when `OPENAI_API_KEY` is set.

```sh
curl -s localhost:8090/complete \
  -H 'content-type: application/json' \
  -d '{"prompt":"Reply with one word: pong"}'
```

## Test

No automated tests yet.

## Build

```bash
just agents build
```

## Migrate

No database.
