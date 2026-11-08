DROP INDEX "session_source_activity";

ALTER TABLE "session" DROP CONSTRAINT "session_source_pair";

ALTER TABLE "session"
  DROP COLUMN "source_activity_id",
  DROP COLUMN "source_provider";
