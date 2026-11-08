ALTER TABLE "session_source" DROP CONSTRAINT "session_source_present";

CREATE TYPE "activity_provider" AS ENUM ('garmin');

ALTER TABLE "session_source"
  ALTER COLUMN "provider" TYPE "activity_provider"
  USING "provider"::"activity_provider";

ALTER TABLE "session_source"
  ADD CONSTRAINT "session_source_present" CHECK ("activity_id" <> '');
