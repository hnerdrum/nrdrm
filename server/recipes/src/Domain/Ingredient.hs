{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.Ingredient
  ( Ingredient (..),
    RecipeIngredient (..),
    CreateIngredientInput (..),
    UpdateIngredientInput (..),
    getAllIngredients,
    getIngredient,
    createIngredient,
    updateIngredient,
    deleteIngredient,
  )
where

import Control.Monad (void)
import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Bifunctor (bimap)
import Data.Text (Text)
import Data.UUID (UUID)
import Domain.Errors (AppError (..), DomainError (..))
import Domain.Unit (Unit (..))
import ORM (DatabaseErrorInfo (..), ORMError (..))
import ORM.Client.Ingredient (IngredientCreate (..), IngredientRow (..), IngredientUpdate (..))
import qualified ORM.Client.Ingredient as Ingredient
import ORM.Db (Db)

newtype CreateIngredientInput = CreateIngredientInput
  { name :: Text
  }
  deriving (Show)

instance FromJSON CreateIngredientInput where
  parseJSON = withObject "CreateIngredientInput" $ \obj -> do
    nameValue <- obj .: "name"
    return $ CreateIngredientInput {name = nameValue}

newtype UpdateIngredientInput = UpdateIngredientInput
  { name :: Text
  }
  deriving (Show)

instance FromJSON UpdateIngredientInput where
  parseJSON = withObject "UpdateIngredientInput" $ \obj -> do
    nameValue <- obj .: "name"
    return $ UpdateIngredientInput {name = nameValue}

data RecipeIngredient = RecipeIngredient
  { id :: UUID,
    name :: Text,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show)

$(deriveJSON defaultOptions ''RecipeIngredient)

data Ingredient = Ingredient
  { id :: UUID,
    name :: Text
  }
  deriving (Show)

$(deriveJSON defaultOptions ''Ingredient)

getAllIngredients :: Db [Ingredient]
getAllIngredients =
  map fromIngredientRow <$> Ingredient.findMany Ingredient.emptyQuery

getIngredient :: UUID -> Db (Either AppError Ingredient)
getIngredient ingredientId =
  bimap fromIngredientError fromIngredientRow
    <$> Ingredient.findUniqueOrFail ingredientId

createIngredient :: CreateIngredientInput -> Db (Either AppError Ingredient)
createIngredient input =
  bimap fromIngredientError fromIngredientRow
    <$> Ingredient.create (toIngredientCreate input)

updateIngredient :: UUID -> UpdateIngredientInput -> Db (Either AppError Ingredient)
updateIngredient ingredientId input =
  bimap fromIngredientError fromIngredientRow
    <$> Ingredient.update ingredientId (toIngredientUpdate input)

deleteIngredient :: UUID -> Db ()
deleteIngredient ingredientId = void (Ingredient.delete ingredientId)

fromIngredientRow :: IngredientRow -> Ingredient
fromIngredientRow row =
  Ingredient
    { id = row.id,
      name = row.name
    }

toIngredientCreate :: CreateIngredientInput -> IngredientCreate
toIngredientCreate input =
  IngredientCreate
    { id = Nothing,
      createdAt = Nothing,
      updatedAt = Nothing,
      name = input.name
    }

toIngredientUpdate :: UpdateIngredientInput -> IngredientUpdate
toIngredientUpdate input =
  IngredientUpdate
    { name = Just input.name,
      createdAt = Nothing,
      updatedAt = Nothing
    }

fromIngredientError :: ORMError -> AppError
fromIngredientError err =
  case err of
    RecordNotFound ingredientId -> AppError NotFoundError "Ingredient could not be found" (object ["ingredientId" .= ingredientId])
    MultipleRecordsFound ingredientId -> AppError MultipleEntitiesError "Found multiple ingredients with matching ID" (object ["ingredientId" .= ingredientId])
    UniqueViolation message -> AppError ConflictError message (object [])
    ForeignKeyViolation message -> AppError ConflictError message (object [])
    NotNullViolation message -> AppError ConflictError message (object [])
    EmptyWhere message -> AppError InternalError message (object [])
    DatabaseError DatabaseErrorInfo {message} -> AppError InternalError message (object [])
    DriverError _ message -> AppError InternalError message (object [])
    UnsupportedIncludeModifier message -> AppError InternalError message (object [])
