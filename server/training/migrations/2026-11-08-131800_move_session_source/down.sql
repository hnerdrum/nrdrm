ALTER TABLE "session"
  ADD COLUMN "source_provider" TEXT,
  ADD COLUMN "source_activity_id" TEXT;

UPDATE "session" AS session
SET
  "source_provider" = session_source."provider",
  "source_activity_id" = session_source."activity_id"
FROM "session_source"
WHERE session_source."session_id" = session."id";

DROP TABLE "session_source";

ALTER TABLE "session"
  ADD CONSTRAINT "session_source_pair" CHECK (
    (
      "source_provider" IS NULL
      AND "source_activity_id" IS NULL
    )
    OR (
      "source_provider" IS NOT NULL
      AND "source_activity_id" IS NOT NULL
    )
  );

CREATE UNIQUE INDEX "session_source_activity"
  ON "session" ("source_provider", "source_activity_id")
  WHERE
    "source_provider" IS NOT NULL
    AND "source_activity_id" IS NOT NULL;
