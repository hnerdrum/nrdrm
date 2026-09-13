# delete-container-images

TypeScript job that prunes old tags in the Scaleway container registry. Not part of local app development.

## Run

```bash
cd cron/delete-container-images
cp .env.example .env
npm install
npm run dev
```

Requires `SCALEWAY_API_KEY` and `SCALEWAY_CONTAINER_REGISTRY_BASE_URL`.

## Test

No automated tests yet.

## Build

```bash
npm run build
```

## Migrate

Not applicable.
