import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import { Effect, Layer } from "effect";
import pg from "pg";
import { config } from "./config.js";

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
    ).pipe(Effect.map((pool) => drizzle(pool))),
  ),
);
