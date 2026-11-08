ALTER TABLE "session"
  ADD COLUMN "source_provider" TEXT,
  ADD COLUMN "source_activity_id" TEXT;

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
