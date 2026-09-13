# delete-container-images

TypeScript job that prunes old tags in the Scaleway container registry. Not part of local app development.

## Run

```bash
cp .env.example .env
npm install
just delete-images run
```

Requires `SCALEWAY_API_KEY` and `SCALEWAY_CONTAINER_REGISTRY_BASE_URL`.

## Test

No automated tests yet.

## Build

```bash
just delete-images build
```

## Migrate

Not applicable.
