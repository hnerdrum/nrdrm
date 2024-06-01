CREATE TYPE "token_status" AS ENUM ('NORMAL', 'WITHDRAWN', 'EXPIRED');

CREATE TABLE "auth_token" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4 () PRIMARY KEY,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "value" TEXT NOT NULL,
  "status" token_status NOT NULL,
  "user_id" UUID REFERENCES "user_account" (id) ON UPDATE CASCADE ON DELETE CASCADE
);

ALTER TABLE "auth_token"
ADD CONSTRAINT unique_auth_token_value_user_id UNIQUE ("value", "user_id");
