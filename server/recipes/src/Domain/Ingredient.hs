{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.Ingredient
  ( Ingredient (..),
    RecipeIngredient (..),
    getAllIngredients,
    getIngredient,
    createIngredient,
    updateIngredient,
    deleteIngredient,
  )
where

import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Bifunctor (bimap)
import Data.Pool (Pool)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.Ingredient (CreateIngredientInput (..), Unit (..), UpdateIngredientInput (..))
import Database.PostgreSQL.Simple (Connection)
import Domain.Errors (AppError (..), DomainError (..))
import ORM (ORMError (..))
import qualified ORM.Client.Ingredient as Ingredient
import ORM.Schema.Ingredient (IngredientCreate (..), IngredientRow (..), IngredientUpdate (..))

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

getAllIngredients :: Pool Connection -> IO [Ingredient]
getAllIngredients pool = do
  ingredientRows <- Ingredient.findAll pool
  return $ map fromIngredientRow ingredientRows

getIngredient :: Pool Connection -> UUID -> IO (Either AppError Ingredient)
getIngredient pool ingredientId =
  bimap fromIngredientError fromIngredientRow
    <$> Ingredient.findUniqueOrError pool ingredientId

createIngredient :: Pool Connection -> CreateIngredientInput -> IO (Either AppError Ingredient)
createIngredient pool input =
  bimap fromIngredientError fromIngredientRow
    <$> Ingredient.create pool (toIngredientCreate input)

updateIngredient :: Pool Connection -> UUID -> UpdateIngredientInput -> IO (Either AppError Ingredient)
updateIngredient pool ingredientId input =
  bimap fromIngredientError fromIngredientRow
    <$> Ingredient.update pool ingredientId (toIngredientUpdate input)

deleteIngredient :: Pool Connection -> UUID -> IO ()
deleteIngredient pool ingredientId = do
  _ <- Ingredient.deleteById pool ingredientId
  return ()

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
