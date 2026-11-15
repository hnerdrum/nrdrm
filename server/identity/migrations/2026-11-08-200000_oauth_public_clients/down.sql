DROP TABLE "authorization_code";

DROP INDEX oauth_client_manual_name;

ALTER TABLE "oauth_client" DROP CONSTRAINT oauth_client_public_secret;
ALTER TABLE "oauth_client" DROP CONSTRAINT oauth_client_registered_via;

ALTER TABLE "oauth_client" DROP COLUMN "registered_via";
ALTER TABLE "oauth_client" DROP COLUMN "redirect_uris";

DELETE FROM "oauth_client" WHERE "secret_hash" IS NULL;
ALTER TABLE "oauth_client" ALTER COLUMN "secret_hash" SET NOT NULL;

ALTER TABLE "oauth_client"
  ADD CONSTRAINT unique_oauth_client_name UNIQUE ("name");
