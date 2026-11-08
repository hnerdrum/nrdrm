ALTER TABLE "training_session" RENAME CONSTRAINT "training_session_pkey" TO "session_pkey";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "training_session_source_pkey" TO "session_source_pkey";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "training_session_source_activity" TO "session_source_activity";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "training_session_source_present" TO "session_source_present";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "training_session_source_session_id_fkey" TO "session_source_session_id_fkey";

ALTER TABLE "training_session_source" RENAME TO "session_source";
ALTER TABLE "training_session" RENAME TO "session";
