CREATE TABLE "refresh_token" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "token_hash" TEXT NOT NULL,
  "client_id" UUID NOT NULL REFERENCES "oauth_client" (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "user_id" UUID NOT NULL REFERENCES "user_account" (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "resource" TEXT NOT NULL,
  "scope" TEXT NOT NULL,
  "family_id" UUID NOT NULL,
  "expires_at" TIMESTAMPTZ(6) NOT NULL,
  "revoked_at" TIMESTAMPTZ(6),
  "replaced_by" UUID,
  CONSTRAINT unique_refresh_token_hash UNIQUE ("token_hash")
);

CREATE INDEX refresh_token_family_id ON "refresh_token" ("family_id");

ALTER TABLE "access_token" ADD COLUMN "scope" TEXT;
