ALTER TABLE "session" RENAME TO "training_session";
ALTER TABLE "session_source" RENAME TO "training_session_source";

ALTER TABLE "training_session" RENAME CONSTRAINT "session_pkey" TO "training_session_pkey";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "session_source_pkey" TO "training_session_source_pkey";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "session_source_activity" TO "training_session_source_activity";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "session_source_present" TO "training_session_source_present";
ALTER TABLE "training_session_source"
  RENAME CONSTRAINT "session_source_session_id_fkey" TO "training_session_source_session_id_fkey";
