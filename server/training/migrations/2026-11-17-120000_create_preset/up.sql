CREATE TABLE "training_preset" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "name" TEXT NOT NULL,
  "body" JSONB NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  CONSTRAINT "training_preset_name_present" CHECK (btrim("name") <> '')
);

CREATE UNIQUE INDEX "training_preset_name" ON "training_preset" (lower("name"));
