CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE "session" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "on_date" DATE NOT NULL,
  "body" JSONB NOT NULL
);
