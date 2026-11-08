ALTER TABLE "session_source" DROP CONSTRAINT "session_source_present";

ALTER TABLE "session_source"
  ALTER COLUMN "provider" TYPE TEXT
  USING "provider"::TEXT;

DROP TYPE "activity_provider";

ALTER TABLE "session_source"
  ADD CONSTRAINT "session_source_present" CHECK (
    "provider" <> '' AND "activity_id" <> ''
  );
