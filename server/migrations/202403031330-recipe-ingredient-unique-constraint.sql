ALTER TABLE "recipe_ingredient"
ADD CONSTRAINT unique_recipe_id_ingredient_id UNIQUE ("recipe_id", "ingredient_id");