{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module ORM.Schema.Ingredient
  ( IngredientTable (..),
    IngredientRow (..),
    IngredientCreate (..),
    IngredientUpdate (..),
    ingredientId,
    ingredientCreatedAt,
    ingredientUpdatedAt,
    ingredientName,
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), setValue)
import ORM.Update (Updatable (..), emptyUpdate, setField)

data IngredientTable = IngredientTable

type instance PrimaryKeyType IngredientTable = UUID

instance Entity IngredientTable where
  tableName = "ingredient"
  primaryKey = ingredientId

instance Insertable IngredientTable where
  type CreateInput IngredientTable = IngredientCreate
  toInsertBuilder input =
    setValue ingredientName input.name

instance Updatable IngredientTable where
  type UpdateInput IngredientTable = IngredientUpdate
  toUpdateBuilder input =
    case input.name of
      Nothing -> emptyUpdate @IngredientTable
      Just n -> setField ingredientName n (emptyUpdate @IngredientTable)

data IngredientRow = IngredientRow
  { id :: UUID,
    createdAt :: UTCTime,
    updatedAt :: UTCTime,
    name :: Text
  }
  deriving (Show)

newtype IngredientCreate = IngredientCreate
  { name :: Text
  }
  deriving (Show, Eq)

newtype IngredientUpdate = IngredientUpdate
  { name :: Maybe Text
  }
  deriving (Show, Eq)

instance FromRow IngredientRow where
  fromRow = IngredientRow <$> field <*> field <*> field <*> field

ingredientId :: Field IngredientTable UUID
ingredientId = Field "id" "id"

ingredientCreatedAt :: Field IngredientTable UTCTime
ingredientCreatedAt = Field "createdAt" "created_at"

ingredientUpdatedAt :: Field IngredientTable UTCTime
ingredientUpdatedAt = Field "updatedAt" "updated_at"

ingredientName :: Field IngredientTable Text
ingredientName = Field "name" "name"
