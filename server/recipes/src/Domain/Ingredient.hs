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
import ORM (ORMError (..), runDb)
import ORM.Client.Ingredient (IngredientCreate (..), IngredientRow (..), IngredientUpdate (..))
import qualified ORM.Client.Ingredient as Ingredient
import ORM.Db (DbPool)

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

getAllIngredients :: DbPool -> IO [Ingredient]
getAllIngredients pool =
  map fromIngredientRow <$> runDb pool (Ingredient.findMany Ingredient.emptyQuery)

getIngredient :: DbPool -> UUID -> IO (Either AppError Ingredient)
getIngredient pool ingredientId =
  bimap fromIngredientError fromIngredientRow
    <$> runDb pool (Ingredient.findUniqueOrFail ingredientId)

createIngredient :: DbPool -> CreateIngredientInput -> IO (Either AppError Ingredient)
createIngredient pool input =
  bimap fromIngredientError fromIngredientRow
    <$> runDb pool (Ingredient.create (toIngredientCreate input))

updateIngredient :: DbPool -> UUID -> UpdateIngredientInput -> IO (Either AppError Ingredient)
updateIngredient pool ingredientId input =
  bimap fromIngredientError fromIngredientRow
    <$> runDb pool (Ingredient.update ingredientId (toIngredientUpdate input))

deleteIngredient :: DbPool -> UUID -> IO ()
deleteIngredient pool ingredientId =
  void (runDb pool (Ingredient.delete ingredientId))

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
    DatabaseError message -> AppError InternalError message (object [])
