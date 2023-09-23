{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.Recipe
    (
      Recipe(..)
    , getAllRecipes
    , getRecipe
    , createRecipe
    , updateRecipe
    , deleteRecipe
    ) where

import Control.Monad
import Data.Aeson
import Data.Aeson.TH
import qualified Data.List.NonEmpty as NE
import Data.Maybe
import Data.Text hiding (map, head, null, filter, length, zip)
import Data.Time
import Data.UUID hiding (null)
import qualified Data.UUID.V4 as V4
import qualified Data.Map as Map
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.Recipe (DbRecipeIngredient(..), CreateRecipeInput(..), getCreateRecipeInput, getCreateRecipeIngredientInput, UpdateRecipeInput(..), getUpdateRecipeIngredientInput)
import Domain.Errors (RecipeError(..))
import Domain.Ingredient (RecipeIngredient(..), toRecipeIngredient)

data Recipe = Recipe
  { id          :: UUID
  , createdAt   :: UTCTime
  , updatedAt   :: UTCTime
  , name        :: Text
  , description :: Text
  , ingredients :: [RecipeIngredient]
  } deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

getAllRecipes :: Pool PGSimple.Connection -> IO [Recipe]
getAllRecipes pool =
  withResource pool $ \conn -> do
    dbRecipeIngredients <- PGSimple.query_ conn
      [sql|
        SELECT r.id, r.created_at, r.updated_at, r.name, r.description,
               i.id, i.created_at, i.updated_at, i.name, ri.amount, ri.unit
        FROM recipe r
        LEFT JOIN recipe_ingredient ri ON r.id = ri.recipe_id
        LEFT JOIN ingredient i ON i.id = ri.ingredient_id
      |]
    return $ mapDbRecipeIngredients dbRecipeIngredients

getRecipe :: Pool PGSimple.Connection -> UUID -> IO (Either RecipeError Recipe)
getRecipe pool recipeId =
  withResource pool $ \conn -> getRecipeById conn recipeId

createRecipe :: Pool PGSimple.Connection -> CreateRecipeInput -> IO (Either RecipeError Recipe)
createRecipe pool recipe =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      recipeId <- V4.nextRandom
      _ <- PGSimple.execute conn
        [sql|
          INSERT INTO recipe (id, name, description)
          VALUES (?, ?, ?)
        |] $ getCreateRecipeInput recipeId recipe
      _ <- PGSimple.executeMany conn
        [sql|
          INSERT INTO recipe_ingredient (recipe_id, ingredient_id, amount, unit)
          VALUES (?, ?, ?, ?)
        |] $ getCreateRecipeIngredientInput recipeId recipe
      getRecipeById conn recipeId

updateRecipe :: Pool PGSimple.Connection -> UUID -> UpdateRecipeInput -> IO (Either RecipeError Recipe)
updateRecipe pool recipeId updateRecipeInput =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      now <- getCurrentTime
      _ <- PGSimple.execute conn
        [sql|
          UPDATE recipe SET updated_at = ?, name = COALESCE(?, name), description = COALESCE(?, description)
          WHERE id = ?
        |] (now, updateRecipeInput.name, updateRecipeInput.description, recipeId)
      forM_ (getUpdateRecipeIngredientInput recipeId updateRecipeInput) $ \params ->
        PGSimple.execute conn
          [sql|
            UPDATE recipe_ingredient SET amount = COALESCE(?, amount), unit = COALESCE(?, unit)
            WHERE recipe_id = ? AND ingredient_id = ?
          |] params
      getRecipeById conn recipeId

deleteRecipe :: Pool PGSimple.Connection -> UUID -> IO ()
deleteRecipe pool recipeId =
  withResource pool $ \conn -> do
    PGSimple.withTransaction conn $ do
      _ <- PGSimple.execute conn
        [sql|
          DELETE FROM recipe_ingredient
          WHERE recipe_id = ?
        |] $ PGSimple.Only recipeId
      _ <- PGSimple.execute conn
        [sql|
          DELETE FROM recipe
          WHERE id = ?
        |] $ PGSimple.Only recipeId
      return ()

getRecipeById :: PGSimple.Connection -> UUID -> IO (Either RecipeError Recipe)
getRecipeById conn recipeId = do
  dbRecipeIngredients <- PGSimple.query conn
    [sql|
      SELECT r.id, r.created_at, r.updated_at, r.name, r.description,
      i.id, i.created_at , i.updated_at, i.name, ri.amount, ri.unit
      FROM recipe r
      LEFT JOIN recipe_ingredient ri ON r.id = ri.recipe_id
      LEFT JOIN ingredient i ON i.id = ri.ingredient_id
      WHERE r.id = ?
    |] $ PGSimple.Only recipeId
  return $ reduceDbRecipeIngredients dbRecipeIngredients

mapDbRecipeIngredients :: [DbRecipeIngredient] -> [Recipe]
mapDbRecipeIngredients dbRecipeIngredients =
  map toRecipe $ groupById dbRecipeIngredients

reduceDbRecipeIngredients :: [DbRecipeIngredient] -> Either RecipeError Recipe
reduceDbRecipeIngredients dbRecipeIngredients
  | null recipeGroups        = Left RecipeNotFound
  | length recipeGroups == 1 = Right $ toRecipe $ head recipeGroups
  | otherwise                = Left MultipleRecipesFound
  where
    recipeGroups = groupById dbRecipeIngredients

toRecipe :: NE.NonEmpty DbRecipeIngredient -> Recipe
toRecipe dbRIs =
  Recipe
    { id = dbRecipeId dbRecipeIngredient
    , createdAt = dbRecipeCreatedAt dbRecipeIngredient
    , updatedAt = dbRecipeUpdatedAt dbRecipeIngredient
    , name = dbRecipeName dbRecipeIngredient
    , description = dbRecipeDescription dbRecipeIngredient
    , ingredients = catMaybes $ NE.toList $ NE.map toRecipeIngredient dbRIs
    }

    where dbRecipeIngredient = NE.head dbRIs

groupById :: [DbRecipeIngredient] -> [NE.NonEmpty DbRecipeIngredient]
groupById dbRI = map NE.fromList $ filter (not . null) $ Map.elems groups
  where groups = Map.fromListWith (++) [(dbRecipeId ri, [ri]) | ri <- dbRI]
