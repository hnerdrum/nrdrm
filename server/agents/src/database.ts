import { fileURLToPath } from "node:url";
import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import { Effect, Layer } from "effect";
import pg from "pg";
import { config } from "./config.js";

const migrationsFolder = fileURLToPath(new URL("../drizzle", import.meta.url));

export class Database extends Effect.Tag("Database")<
  Database,
  NodePgDatabase
>() {}

export const DatabaseLive = Layer.scoped(
  Database,
  Effect.flatMap(config, ({ databaseUrl }) =>
    Effect.acquireRelease(
      Effect.sync(() => new pg.Pool({ connectionString: databaseUrl })),
      (pool) => Effect.promise(() => pool.end()),
    ).pipe(
      Effect.tap((pool) =>
        Effect.tryPromise({
          try: () => migrate(drizzle(pool), { migrationsFolder }),
          catch: (cause) => cause,
        }).pipe(
          Effect.tapError((cause) =>
            Effect.logError(
              cause instanceof Error
                ? cause.cause instanceof Error
                  ? cause.cause.message
                  : cause.message
                : "migration failed",
            ),
          ),
        ),
      ),
      Effect.map((pool) => drizzle(pool)),
    ),
  ),
);
