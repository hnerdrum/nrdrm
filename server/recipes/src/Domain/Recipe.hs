{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.Recipe
  ( Recipe (..),
    getAllRecipes,
    getRecipe,
    createRecipe,
    updateRecipe,
    deleteRecipe,
  )
where

import Control.Monad (forM_)
import Data.Aeson (object, (.=))
import Data.Aeson.TH (defaultOptions, deriveJSON)
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Pool (Pool, withResource)
import Data.Text (Text)
import Data.Time (getCurrentTime)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as V4
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.Recipe
  ( CreateRecipeInput (..),
    UpdateRecipeInput (..),
    getCreateRecipeIngredientInput,
    getCreateRecipeInput,
    getUpdateRecipeIngredientInput,
  )
import Domain.Errors (AppError (..), DomainError (..), addErrorContext)
import Domain.Ingredient (RecipeIngredient (..))
import qualified ORM.Client.Recipe as Recipe
import ORM.Schema.Ingredient (IngredientRow (..))
import ORM.Schema.Recipe (RecipeRow (..))
import ORM.Schema.RecipeInclude
  ( RecipeIngredientWithIngredient (..),
    RecipeWithIngredients (..),
  )
import ORM.Schema.RecipeIngredient (RecipeIngredientRow (..))

data Recipe = Recipe
  { id :: UUID,
    name :: Text,
    description :: Text,
    ingredients :: [RecipeIngredient]
  }
  deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

getAllRecipes :: Pool PGSimple.Connection -> IO [Recipe]
getAllRecipes pool = do
  recipes <- Recipe.findAllWithIngredients pool
  pure $ map fromRecipeWithIngredients recipes

getRecipe :: Pool PGSimple.Connection -> UUID -> IO (Either AppError Recipe)
getRecipe pool recipeId = do
  mRecipe <- Recipe.findUniqueWithIngredients pool recipeId
  pure $
    case mRecipe of
      Nothing ->
        Left $
          addErrorContext (object ["recipeId" .= recipeId]) $
            AppError NotFoundError "Recipe could not be found" (object [])
      Just recipeWithIngredients ->
        Right (fromRecipeWithIngredients recipeWithIngredients)

createRecipe :: Pool PGSimple.Connection -> CreateRecipeInput -> IO (Either AppError Recipe)
createRecipe pool recipe = do
  recipeId <-
    withResource pool $ \conn ->
      PGSimple.withTransaction conn $ do
        newRecipeId <- V4.nextRandom
        _ <-
          PGSimple.execute
            conn
            [sql|
            INSERT INTO recipe (id, name, description)
            VALUES (?, ?, ?)
          |]
            $ getCreateRecipeInput newRecipeId recipe
        _ <-
          PGSimple.executeMany
            conn
            [sql|
            INSERT INTO recipe_ingredient (recipe_id, ingredient_id, amount, unit)
            VALUES (?, ?, ?, ?)
          |]
            $ getCreateRecipeIngredientInput newRecipeId recipe
        pure newRecipeId
  getRecipe pool recipeId

updateRecipe :: Pool PGSimple.Connection -> UUID -> UpdateRecipeInput -> IO (Either AppError Recipe)
updateRecipe pool recipeId updateRecipeInput = do
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      now <- getCurrentTime
      _ <-
        PGSimple.execute
          conn
          [sql|
          UPDATE recipe SET updated_at = ?, name = COALESCE(?, name), description = COALESCE(?, description)
          WHERE id = ?
        |]
          (now, updateRecipeInput.name, updateRecipeInput.description, recipeId)
      _ <-
        PGSimple.execute
          conn
          [sql|
          DELETE from recipe_ingredient
          WHERE recipe_id = ?
        |]
          $ PGSimple.Only recipeId
      forM_ (getUpdateRecipeIngredientInput recipeId updateRecipeInput) $ \params ->
        PGSimple.execute
          conn
          [sql|
            INSERT INTO recipe_ingredient (recipe_id, ingredient_id, amount, unit)
            VALUES (?, ?, ?, ?)
            ON CONFLICT (recipe_id, ingredient_id)
            DO UPDATE SET amount = EXCLUDED.amount, unit = EXCLUDED.unit
         |]
          params
  getRecipe pool recipeId

deleteRecipe :: Pool PGSimple.Connection -> UUID -> IO ()
deleteRecipe pool recipeId =
  withResource pool $ \conn -> do
    PGSimple.withTransaction conn $ do
      _ <-
        PGSimple.execute
          conn
          [sql|
          DELETE FROM recipe_ingredient
          WHERE recipe_id = ?
        |]
          $ PGSimple.Only recipeId
      _ <-
        PGSimple.execute
          conn
          [sql|
          DELETE FROM recipe
          WHERE id = ?
        |]
          $ PGSimple.Only recipeId
      return ()

fromRecipeWithIngredients :: RecipeWithIngredients -> Recipe
fromRecipeWithIngredients (RecipeWithIngredients (RecipeRow rid _ _ rname rdesc) ingredients) =
  Recipe
    { id = rid,
      name = rname,
      description = fromMaybe "" rdesc,
      ingredients = mapMaybe fromRecipeIngredientWithIngredient ingredients
    }

fromRecipeIngredientWithIngredient :: RecipeIngredientWithIngredient -> Maybe RecipeIngredient
fromRecipeIngredientWithIngredient
  ( RecipeIngredientWithIngredient
      (RecipeIngredientRow _ _ amount unit)
      (Just (IngredientRow iid _ _ iname))
    ) =
    Just
      RecipeIngredient
        { id = iid,
          name = iname,
          amount,
          unit
        }
fromRecipeIngredientWithIngredient _ = Nothing
