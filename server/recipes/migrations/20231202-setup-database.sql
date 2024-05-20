CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE "unit" AS ENUM ('g', 'ml', 'tsp', 'tbsp', 'qty');

CREATE TABLE "recipe" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4 () PRIMARY KEY,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "name" TEXT NOT NULL,
  "description" TEXT
);

CREATE TABLE "ingredient" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "name" TEXT NOT NULL
);

CREATE TABLE "recipe_ingredient" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "recipe_id" UUID REFERENCES recipe (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "ingredient_id" UUID REFERENCES ingredient (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "amount" Int NOT NULL,
  "unit" unit
);