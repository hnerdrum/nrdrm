## Databases

### Running locally

```sh
docker compose -f docker-databases.yml up --build -d;
```

### Recipes

```sql
CREATE TABLE "recipe" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4 () PRIMARY KEY,
  "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT
);

CREATE TYPE "unit" AS ENUM ('g', 'dl', 'tsp', 'tbsp', 'qty');

CREATE TABLE "ingredient" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "name" TEXT NOT NULL,
  "amount" DECIMAL(4, 2) NOT NULL,
  "unit" unit
);

CREATE TABLE "recipe_ingredient" (
  "recipeId" UUID REFERENCES recipe (id) ON UPDATE CASCADE ON DELETE CASCADE,
  "ingredientId" UUID REFERENCES ingredient (id) ON UPDATE CASCADE ON DELETE CASCADE
);
```
