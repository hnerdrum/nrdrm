{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module Domain.Recipe
  ( Recipe (..),
    CreateRecipeInput (..),
    CreateRecipeIngredientInput (..),
    UpdateRecipeInput (..),
    UpdateRecipeIngredientInput (..),
    getAllRecipes,
    getRecipe,
    createRecipe,
    updateRecipe,
    deleteRecipe,
  )
where

import Control.Monad (void)
import Data.Aeson (FromJSON (parseJSON), object, withObject, (.:), (.:?))
import Data.Aeson.TH (defaultOptions, deriveJSON)
import Data.Bifunctor (bimap)
import Data.Maybe (mapMaybe)
import Data.Pool (Pool)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection)
import Domain.Errors (AppError (..), DomainError (..))
import Domain.Ingredient (RecipeIngredient (..))
import Domain.Unit (Unit (..))
import ORM (ORMError (..), runDb, withTransaction)
import qualified ORM.Client.Recipe as Recipe
import ORM.Core (NullableValue (..))
import ORM.Schema.Ingredient (IngredientRow (..))
import ORM.Schema.Recipe (RecipeCreate (..), RecipeRow (..), RecipeUpdate (..))
import ORM.Schema.RecipeInclude
  ( RecipeIngredientWithIngredient (..),
    RecipeWithIngredients (..),
  )
import ORM.Schema.RecipeIngredient (RecipeIngredientRow (..))

data CreateRecipeInput = CreateRecipeInput
  { name :: Text,
    description :: Text,
    ingredients :: [CreateRecipeIngredientInput]
  }
  deriving (Show)

instance FromJSON CreateRecipeInput where
  parseJSON = withObject "CreateRecipeInput" $ \obj -> do
    nameValue <- obj .: "name"
    descriptionValue <- obj .: "description"
    ingredientsValue <- obj .: "ingredients"
    return $
      CreateRecipeInput
        { name = nameValue,
          description = descriptionValue,
          ingredients = ingredientsValue
        }

data UpdateRecipeInput = UpdateRecipeInput
  { name :: Maybe Text,
    description :: Maybe Text,
    ingredients :: Maybe [UpdateRecipeIngredientInput]
  }
  deriving (Show)

instance FromJSON UpdateRecipeInput where
  parseJSON = withObject "UpdateRecipeInput" $ \obj -> do
    nameValue <- obj .:? "name"
    descriptionValue <- obj .:? "description"
    ingredientsValue <- obj .:? "ingredients"
    return $
      UpdateRecipeInput
        { name = nameValue,
          description = descriptionValue,
          ingredients = ingredientsValue
        }

data CreateRecipeIngredientInput = CreateRecipeIngredientInput
  { id :: UUID,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show)

instance FromJSON CreateRecipeIngredientInput where
  parseJSON = withObject "CreateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "id"
    amountValue <- obj .: "amount"
    unitValue <- obj .: "unit"
    return $
      CreateRecipeIngredientInput
        { id = ingredientIdValue,
          amount = amountValue,
          unit = unitValue
        }

data UpdateRecipeIngredientInput = UpdateRecipeIngredientInput
  { id :: UUID,
    amount :: Maybe Int,
    unit :: Maybe Unit
  }
  deriving (Show)

instance FromJSON UpdateRecipeIngredientInput where
  parseJSON = withObject "UpdateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "id"
    amountValue <- obj .:? "amount"
    unitValue <- obj .:? "unit"
    return $
      UpdateRecipeIngredientInput
        { id = ingredientIdValue,
          amount = amountValue,
          unit = unitValue
        }

data Recipe = Recipe
  { id :: UUID,
    name :: Text,
    description :: Maybe Text,
    ingredients :: [RecipeIngredient]
  }
  deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

getAllRecipes :: Pool Connection -> IO [Recipe]
getAllRecipes pool =
  map fromRecipeWithIngredients <$> runDb pool (Recipe.findMany Recipe.withIngredients)

getRecipe :: Pool Connection -> UUID -> IO (Either AppError Recipe)
getRecipe pool recipeId =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> runDb pool (Recipe.findUniqueOrFail Recipe.withIngredients recipeId)

createRecipe :: Pool Connection -> CreateRecipeInput -> IO (Either AppError Recipe)
createRecipe pool input =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> withTransaction pool (Recipe.create Recipe.withIngredients (toRecipeWriteCreate input))

updateRecipe :: Pool Connection -> UUID -> UpdateRecipeInput -> IO (Either AppError Recipe)
updateRecipe pool recipeId input =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> withTransaction pool (Recipe.update Recipe.withIngredients recipeId (toRecipeWriteUpdate input))

toRecipeWriteCreate :: CreateRecipeInput -> Recipe.RecipeWriteCreate
toRecipeWriteCreate input =
  Recipe.RecipeWriteCreate
    { root =
        RecipeCreate
          { id = Nothing,
            createdAt = Nothing,
            updatedAt = Nothing,
            name = input.name,
            description = Value input.description
          },
      ingredients = map toRecipeIngredientNestedCreate input.ingredients
    }

toRecipeWriteUpdate :: UpdateRecipeInput -> Recipe.RecipeWriteUpdate
toRecipeWriteUpdate input =
  Recipe.RecipeWriteUpdate
    { root =
        RecipeUpdate
          { name = input.name,
            createdAt = Nothing,
            updatedAt = Nothing,
            description = maybe Omit Value input.description
          },
      ingredients = fmap (mapMaybe toRecipeIngredientNestedUpdate) input.ingredients
    }

toRecipeIngredientNestedCreate :: CreateRecipeIngredientInput -> Recipe.RecipeIngredientNestedCreate
toRecipeIngredientNestedCreate input =
  Recipe.RecipeIngredientNestedCreate
    { ingredientId = input.id,
      amount = input.amount,
      unit = input.unit
    }

toRecipeIngredientNestedUpdate :: UpdateRecipeIngredientInput -> Maybe Recipe.RecipeIngredientNestedCreate
toRecipeIngredientNestedUpdate input = do
  amount <- input.amount
  unit <- input.unit
  pure
    Recipe.RecipeIngredientNestedCreate
      { ingredientId = input.id,
        amount,
        unit
      }

deleteRecipe :: Pool Connection -> UUID -> IO ()
deleteRecipe pool recipeId =
  void (runDb pool (Recipe.delete recipeId))

fromRecipeError :: ORMError -> AppError
fromRecipeError err =
  case err of
    RecordNotFound message -> AppError NotFoundError message (object [])
    MultipleRecordsFound message -> AppError MultipleEntitiesError message (object [])
    UniqueViolation message -> AppError ConflictError message (object [])
    DatabaseError message -> AppError InternalError message (object [])

fromRecipeWithIngredients :: RecipeWithIngredients -> Recipe
fromRecipeWithIngredients (RecipeWithIngredients (RecipeRow rid _ _ rname rdesc) ingredients) =
  Recipe
    { id = rid,
      name = rname,
      description = rdesc,
      ingredients = mapMaybe fromDbRecipeIngredient ingredients
    }

fromDbRecipeIngredient :: RecipeIngredientWithIngredient -> Maybe RecipeIngredient
fromDbRecipeIngredient
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
fromDbRecipeIngredient _ = Nothing
