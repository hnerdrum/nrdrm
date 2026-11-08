DROP INDEX "session_source_activity";

CREATE TABLE "session_source" (
  "session_id" UUID NOT NULL PRIMARY KEY REFERENCES "session" ("id"),
  "provider" TEXT NOT NULL,
  "activity_id" TEXT NOT NULL,
  CONSTRAINT "session_source_activity" UNIQUE ("provider", "activity_id"),
  CONSTRAINT "session_source_present" CHECK (
    "provider" <> '' AND "activity_id" <> ''
  )
);

INSERT INTO "session_source" ("session_id", "provider", "activity_id")
SELECT "id", "source_provider", "source_activity_id"
FROM "session"
WHERE "source_provider" IS NOT NULL
  AND "source_activity_id" IS NOT NULL;

ALTER TABLE "session" DROP CONSTRAINT "session_source_pair";

ALTER TABLE "session"
  DROP COLUMN "source_activity_id",
  DROP COLUMN "source_provider";
