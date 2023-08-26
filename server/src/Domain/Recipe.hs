{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Recipe
    (
      Recipe(..)
    , getAllRecipes
    , getRecipe
    , RecipeError(..)
    , createRecipe
    , deleteRecipe
    ) where

import Data.Aeson
import Data.Aeson.TH
import qualified Data.List.NonEmpty as NE
import Data.Maybe
import Data.Text hiding (map, head, null, filter, length)
import Data.Time
import Data.UUID hiding (null)
import qualified Data.UUID.V4 as V4
import qualified Data.Map as Map
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.Recipe (DbRecipeIngredient(..), CreateRecipeInput(..), getCreateRecipeInput, getCreateRecipeIngredientInput)
import Domain.Ingredient (Ingredient(..), toIngredient)

data Recipe = Recipe
  { id          :: UUID
  , createdAt   :: UTCTime
  , updatedAt   :: UTCTime
  , name        :: Text
  , description :: Text
  , ingredients :: [Ingredient]
  } deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

data RecipeError = RecipeNotFound | MultipleRecipesFound
  deriving (Eq, Show)

getAllRecipes :: Pool PGSimple.Connection -> IO [Recipe]
getAllRecipes pool =
  withResource pool $ \conn -> do
    dbRecipeIngredients <- PGSimple.query_ conn "SELECT r.id, r.created_at, r.updated_at, r.name, r.description, i.id, i.created_at , i.updated_at, i.name, ri.amount, ri.unit FROM recipe r LEFT JOIN recipe_ingredient ri ON r.id = ri.recipe_id LEFT JOIN ingredient i ON i.id = ri.ingredient_id"
    return $ mapDbRecipeIngredients dbRecipeIngredients

getRecipe :: Pool PGSimple.Connection -> UUID -> IO (Either RecipeError Recipe)
getRecipe pool recipeId =
  withResource pool $ \conn -> do
    dbRecipeIngredients <- PGSimple.query conn ("SELECT r.id, r.created_at, r.updated_at, r.name, r.description, i.id, i.created_at , i.updated_at, i.name, ri.amount, ri.unit FROM recipe r LEFT JOIN recipe_ingredient ri ON r.id = ri.recipe_id LEFT JOIN ingredient i ON i.id = ri.ingredient_id WHERE r.id = ?") $ PGSimple.Only recipeId
    return $ reduceDbRecipeIngredients dbRecipeIngredients

createRecipe :: Pool PGSimple.Connection -> CreateRecipeInput -> IO ()
createRecipe pool newRecipe =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      newRecipeId <- V4.nextRandom
      _ <- PGSimple.execute conn "INSERT INTO recipe (id, name, description) VALUES (?, ?, ?)" $ getCreateRecipeInput newRecipeId newRecipe
      _ <- PGSimple.executeMany conn "INSERT INTO recipe_ingredient (recipe_id, ingredient_id, amount, unit) VALUES (?, ?, ?, ?)" $ getCreateRecipeIngredientInput newRecipeId newRecipe
      return ()

deleteRecipe :: Pool PGSimple.Connection -> UUID -> IO ()
deleteRecipe pool recipeId =
  withResource pool $ \conn -> do
    PGSimple.withTransaction conn $ do
      _ <- PGSimple.execute conn ("DELETE FROM recipe_ingredient WHERE recipe_id = ?") $ PGSimple.Only recipeId
      _ <- PGSimple.execute conn ("DELETE FROM recipe WHERE id = ?") $ PGSimple.Only recipeId
      return ()

mapDbRecipeIngredients :: [DbRecipeIngredient] -> [Recipe]
mapDbRecipeIngredients dbRecipeIngredients =
  map toRecipe $ groupById dbRecipeIngredients

reduceDbRecipeIngredients :: [DbRecipeIngredient] -> Either RecipeError Recipe
reduceDbRecipeIngredients dbRecipeIngredients
  | length recipeGroups == 0 = Left RecipeNotFound
  | length recipeGroups == 1 = Right $ toRecipe $ head recipeGroups
  | otherwise                = Left MultipleRecipesFound
  where
    recipeGroups = groupById dbRecipeIngredients

toRecipe :: NE.NonEmpty DbRecipeIngredient -> Recipe
toRecipe dbRIs =
  Recipe
    { id = dbRecipeId (NE.head dbRIs)
    , createdAt = dbRecipeCreatedAt (NE.head dbRIs)
    , updatedAt = dbRecipeUpdatedAt (NE.head dbRIs)
    , name = dbRecipeName (NE.head dbRIs)
    , description = dbRecipeDescription (NE.head dbRIs)
    , ingredients = catMaybes $ NE.toList $ NE.map toIngredient dbRIs
    }

groupById :: [DbRecipeIngredient] -> [NE.NonEmpty DbRecipeIngredient]
groupById dbRI = map NE.fromList $ filter (not . null) $ Map.elems groups
  where groups = Map.fromListWith (++) [(dbRecipeId ri, [ri]) | ri <- dbRI]
