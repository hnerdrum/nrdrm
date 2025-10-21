{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Domain.Ingredient
  ( Ingredient (..),
    RecipeIngredient (..),
    getAllIngredients,
    fromDbRecipeIngredient,
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
import Database.Recipe (DbRecipeIngredient (..))
import Domain.Errors (AppError (..), DomainError (..))
import ORM (ToInsert (..), ToUpdate (..))
import qualified ORM
import ORM.Schema.Ingredient (IngredientRow (..), IngredientTable, ingredientName)

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

instance ToInsert CreateIngredientInput IngredientTable where
  toInsertBuilder input =
    ORM.setValue ingredientName input.name

instance ToUpdate UpdateIngredientInput IngredientTable where
  toUpdateBuilder input =
    ORM.setField ingredientName input.name (ORM.emptyUpdate @IngredientTable)

getAllIngredients :: Pool Connection -> IO [Ingredient]
getAllIngredients pool = do
  ingredientRows <- ORM.findAll @IngredientTable pool
  return $ map fromIngredientRow ingredientRows

getIngredient :: Pool Connection -> UUID -> IO (Either AppError Ingredient)
getIngredient pool ingredientId =
  bimap fromIngredientError fromIngredientRow
    <$> ORM.findUniqueOrError @IngredientTable pool ingredientId

createIngredient :: Pool Connection -> CreateIngredientInput -> IO (Either AppError Ingredient)
createIngredient pool input =
  bimap fromIngredientError fromIngredientRow
    <$> ORM.createWith @CreateIngredientInput @IngredientTable @IngredientRow pool input

updateIngredient :: Pool Connection -> UUID -> UpdateIngredientInput -> IO (Either AppError Ingredient)
updateIngredient pool ingredientId input =
  bimap fromIngredientError fromIngredientRow
    <$> ORM.updateWith @UpdateIngredientInput @IngredientTable @IngredientRow pool ingredientId input

deleteIngredient :: Pool Connection -> UUID -> IO ()
deleteIngredient pool ingredientId = do
  _ <- ORM.deleteByPk @IngredientTable pool ingredientId
  return ()

fromIngredientRow :: IngredientRow -> Ingredient
fromIngredientRow row =
  Ingredient
    { id = row.id,
      name = row.name
    }

fromIngredientError :: ORM.ORMError -> AppError
fromIngredientError err =
  case err of
    ORM.RecordNotFound ingredientId -> AppError NotFoundError "Ingredient could not be found" (object ["ingredientId" .= ingredientId])
    ORM.MultipleRecordsFound ingredientId -> AppError MultipleEntitiesError "Found multiple ingredients with matching ID" (object ["ingredientId" .= ingredientId])

fromDbRecipeIngredient :: DbRecipeIngredient -> Maybe RecipeIngredient
fromDbRecipeIngredient dbRI = do
  ingredientId <- dbIngredientId dbRI
  ingredientAmount <- dbIngredientAmount dbRI
  ingName <- dbIngredientName dbRI
  ingredientUnit <- dbIngredientUnit dbRI

  return
    RecipeIngredient
      { id = ingredientId,
        name = ingName,
        amount = ingredientAmount,
        unit = ingredientUnit
      }