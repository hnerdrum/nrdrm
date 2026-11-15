ALTER TABLE "oauth_client" ALTER COLUMN "secret_hash" DROP NOT NULL;

ALTER TABLE "oauth_client"
  ADD COLUMN "redirect_uris" TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN "registered_via" TEXT NOT NULL DEFAULT 'manual';

ALTER TABLE "oauth_client"
  ADD CONSTRAINT oauth_client_registered_via
  CHECK ("registered_via" IN ('manual', 'dynamic'));

ALTER TABLE "oauth_client"
  ADD CONSTRAINT oauth_client_public_secret
  CHECK (
    ("registered_via" = 'dynamic' AND "secret_hash" IS NULL AND cardinality("redirect_uris") > 0)
    OR
    ("registered_via" = 'manual' AND "secret_hash" IS NOT NULL)
  );

ALTER TABLE "oauth_client" DROP CONSTRAINT unique_oauth_client_name;

CREATE UNIQUE INDEX oauth_client_manual_name
  ON "oauth_client" ("name")
  WHERE "registered_via" = 'manual';

CREATE TABLE "authorization_code" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "code_hash" TEXT NOT NULL,
  "client_id" UUID NOT NULL REFERENCES "oauth_client" (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "user_id" UUID NOT NULL REFERENCES "user_account" (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "redirect_uri" TEXT NOT NULL,
  "code_challenge" TEXT NOT NULL,
  "resource" TEXT NOT NULL,
  "scope" TEXT NOT NULL,
  "expires_at" TIMESTAMPTZ(6) NOT NULL,
  "used_at" TIMESTAMPTZ(6),
  CONSTRAINT unique_authorization_code_hash UNIQUE ("code_hash")
);
