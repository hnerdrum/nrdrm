{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module Domain.Recipe
  ( Recipe (..),
    getAllRecipes,
    getRecipe,
    createRecipe,
    updateRecipe,
    deleteRecipe,
  )
where

import Data.Aeson (object)
import Data.Aeson.TH (defaultOptions, deriveJSON)
import Data.Bifunctor (bimap)
import Data.Maybe (mapMaybe)
import Data.Pool (Pool)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection)
import Database.Recipe (CreateRecipeInput (..), UpdateRecipeInput (..))
import Domain.Errors (AppError (..), DomainError (..))
import Domain.Ingredient (RecipeIngredient (..))
import ORM (ORMError (..))
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
    description :: Maybe Text,
    ingredients :: [RecipeIngredient]
  }
  deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

getAllRecipes :: Pool Connection -> IO [Recipe]
getAllRecipes pool = do
  recipes <- Recipe.findAll pool Recipe.withIngredients
  pure $ map fromRecipeWithIngredients recipes

getRecipe :: Pool Connection -> UUID -> IO (Either AppError Recipe)
getRecipe pool recipeId =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> Recipe.findUniqueOrError pool Recipe.withIngredients recipeId

createRecipe :: Pool Connection -> CreateRecipeInput -> IO (Either AppError Recipe)
createRecipe pool input =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> Recipe.create pool Recipe.withIngredients input

updateRecipe :: Pool Connection -> UUID -> UpdateRecipeInput -> IO (Either AppError Recipe)
updateRecipe pool recipeId input =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> Recipe.update pool Recipe.withIngredients recipeId input

deleteRecipe :: Pool Connection -> UUID -> IO ()
deleteRecipe pool recipeId = do
  _ <- Recipe.delete pool recipeId
  pure ()

fromRecipeError :: ORMError -> AppError
fromRecipeError err =
  case err of
    RecordNotFound message -> AppError NotFoundError message (object [])
    MultipleRecordsFound message -> AppError MultipleEntitiesError message (object [])

fromRecipeWithIngredients :: RecipeWithIngredients -> Recipe
fromRecipeWithIngredients (RecipeWithIngredients (RecipeRow rid _ _ rname rdesc) ingredients) =
  Recipe
    { id = rid,
      name = rname,
      description = rdesc,
      ingredients = mapMaybe fromRecipeIngredientWithIngredient ingredients
    }

fromRecipeIngredientWithIngredient :: RecipeIngredientWithIngredient -> Maybe RecipeIngredient
fromRecipeIngredientWithIngredient
  ( RecipeIngredientWithIngredient
      (RecipeIngredientRow _ _ _ amount unit)
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
