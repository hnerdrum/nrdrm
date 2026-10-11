import { defineConfig } from "drizzle-kit";
import { Effect } from "effect";
import { config } from "./src/config.js";

export default defineConfig({
  schema: "./src/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: Effect.runSync(config).databaseUrl,
  },
});
