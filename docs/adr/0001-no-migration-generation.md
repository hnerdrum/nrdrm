# Hand-written SQL migrations, not a migrator

Recipes uses [Poppy](https://github.com/hnerdrum/poppy): Schema → Codegen → Client. Prisma also generates and applies migrations; we will not, at least for v0.1.

Schema changes stay as hand-written SQL. Drift-check is how Schema and live Postgres are kept aligned. Auto-migrate (Persistent) is too dangerous for production, and Prisma-style migration generation is a separate product. We would rather document the gap than ship a bad migrator.
