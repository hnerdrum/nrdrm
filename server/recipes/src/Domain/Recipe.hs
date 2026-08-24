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
import Data.Text (Text)
import Data.UUID (UUID)
import Domain.Errors (AppError (..), DomainError (..))
import Domain.Ingredient (RecipeIngredient (..))
import Domain.Unit (Unit (..), fromDbUnit, toDbUnit)
import ORM (DatabaseErrorInfo (..), ORMError (..))
import ORM.Client.Recipe
  ( IngredientRow (..),
    RecipeCreate (..),
    RecipeIngredientRow (..),
    RecipeIngredientWithIngredient (..),
    RecipeRow (..),
    RecipeUpdate (..),
    RecipeWithIngredients (..),
  )
import qualified ORM.Client.Recipe as Recipe
import ORM.Core (NullableValue (..))
import ORM.Db (Db)
import ORM.Where (eq)

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

getAllRecipes :: Db [Recipe]
getAllRecipes =
  map fromRecipeWithIngredients
    <$> Recipe.findMany Recipe.emptyQuery {Recipe.include_ = Recipe.withIngredients}

getRecipe :: UUID -> Db (Either AppError Recipe)
getRecipe recipeId =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> Recipe.findUniqueOrFail
      Recipe.emptyQuery
        { Recipe.include_ = Recipe.withIngredients,
          Recipe.where_ = Just (eq Recipe.recipeId recipeId)
        }

createRecipe :: CreateRecipeInput -> Db (Either AppError Recipe)
createRecipe input =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> Recipe.create Recipe.withIngredients (toRecipeWriteCreate input)

updateRecipe :: UUID -> UpdateRecipeInput -> Db (Either AppError Recipe)
updateRecipe recipeId input =
  bimap fromRecipeError fromRecipeWithIngredients
    <$> Recipe.update Recipe.withIngredients recipeId (toRecipeWriteUpdate input)

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
      ingredients = Recipe.Set (map toRecipeIngredientNestedCreate input.ingredients)
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
      ingredients = fmap (Recipe.Set . mapMaybe toRecipeIngredientNestedUpdate) input.ingredients
    }

toRecipeIngredientNestedCreate :: CreateRecipeIngredientInput -> Recipe.RecipeIngredientNestedCreate
toRecipeIngredientNestedCreate input =
  Recipe.RecipeIngredientNestedCreate
    { ingredientId = input.id,
      amount = input.amount,
      unit = toDbUnit input.unit
    }

toRecipeIngredientNestedUpdate :: UpdateRecipeIngredientInput -> Maybe Recipe.RecipeIngredientNestedCreate
toRecipeIngredientNestedUpdate input = do
  amount <- input.amount
  unit <- input.unit
  pure
    Recipe.RecipeIngredientNestedCreate
      { ingredientId = input.id,
        amount,
        unit = toDbUnit unit
      }

deleteRecipe :: UUID -> Db ()
deleteRecipe recipeId = void (Recipe.delete recipeId)

fromRecipeError :: ORMError -> AppError
fromRecipeError err =
  case err of
    RecordNotFound message -> AppError NotFoundError message (object [])
    MultipleRecordsFound message -> AppError MultipleEntitiesError message (object [])
    UniqueViolation message -> AppError ConflictError message (object [])
    ForeignKeyViolation message -> AppError ConflictError message (object [])
    NotNullViolation message -> AppError ConflictError message (object [])
    EmptyWhere message -> AppError InternalError message (object [])
    InvalidUniqueInput message -> AppError InternalError message (object [])
    DatabaseError DatabaseErrorInfo {message} -> AppError InternalError message (object [])
    DriverError _ message -> AppError InternalError message (object [])
    UnsupportedIncludeModifier message -> AppError InternalError message (object [])

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
          unit = fromDbUnit unit
        }
fromDbRecipeIngredient _ = Nothing
