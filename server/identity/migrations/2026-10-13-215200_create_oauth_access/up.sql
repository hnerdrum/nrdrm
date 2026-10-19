CREATE TABLE "oauth_client" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "name" TEXT NOT NULL,
  "secret_hash" TEXT NOT NULL,
  CONSTRAINT unique_oauth_client_name UNIQUE ("name")
);

CREATE TABLE "oauth_client_audience" (
  "client_id" UUID NOT NULL REFERENCES "oauth_client" (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "audience" TEXT NOT NULL,
  PRIMARY KEY ("client_id", "audience")
);

CREATE TABLE "access_token" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "token_hash" TEXT NOT NULL,
  "client_id" UUID NOT NULL REFERENCES "oauth_client" (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "audience" TEXT NOT NULL,
  "expires_at" TIMESTAMPTZ(6) NOT NULL,
  "revoked_at" TIMESTAMPTZ(6),
  "user_id" UUID REFERENCES "user_account" (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT unique_access_token_hash UNIQUE ("token_hash")
);
