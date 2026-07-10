{-# LANGUAGE TypeApplications #-}

module ORM.Client.Recipe
  ( findAllWithIngredients,
    findUniqueWithIngredients,
  )
where

import Data.Pool (Pool)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection)
import ORM.Include (findManyWith)
import ORM.Query (whereEq)
import ORM.Schema.Recipe (RecipeTable, recipeId)
import ORM.Schema.RecipeInclude
  ( RecipeWithIngredients (..),
    recipeIngredientsInclude,
  )

findAllWithIngredients :: Pool Connection -> IO [RecipeWithIngredients]
findAllWithIngredients pool =
  findManyWith @RecipeTable pool recipeIngredientsInclude id

findUniqueWithIngredients :: Pool Connection -> UUID -> IO (Maybe RecipeWithIngredients)
findUniqueWithIngredients pool pk = do
  results <-
    findManyWith @RecipeTable pool recipeIngredientsInclude (whereEq recipeId pk)
  case results of
    [recipe] -> pure (Just recipe)
    [] -> pure Nothing
    _ -> error "findUniqueWithIngredients: multiple recipes matched primary key"
