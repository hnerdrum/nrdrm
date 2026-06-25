{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE OverloadedRecordDot #-}
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
import ORM.Insert (Insertable (..), setMaybe, setValue)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe)

data IngredientTable = IngredientTable

type instance PrimaryKeyType IngredientTable = UUID

instance Entity IngredientTable where
  tableName = "ingredient"
  primaryKey = ingredientId

instance Insertable IngredientTable where
  type CreateInput IngredientTable = IngredientCreate
  toInsertBuilder input =
    setMaybe ingredientUpdatedAt input.updatedAt $
      setMaybe ingredientCreatedAt input.createdAt $
        setMaybe ingredientId input.id $
          setValue ingredientName input.name

instance Updatable IngredientTable where
  type UpdateInput IngredientTable = IngredientUpdate
  updatedAtField = Just ingredientUpdatedAt
  toUpdateBuilder input =
    setFieldMaybe ingredientUpdatedAt input.updatedAt $
      setFieldMaybe ingredientCreatedAt input.createdAt $
        setFieldMaybe ingredientName input.name (emptyUpdate @IngredientTable)

data IngredientRow = IngredientRow
  { id :: UUID,
    createdAt :: UTCTime,
    updatedAt :: UTCTime,
    name :: Text
  }
  deriving (Show)

data IngredientCreate = IngredientCreate
  { id :: Maybe UUID,
    createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
    name :: Text
  }
  deriving (Show, Eq)

data IngredientUpdate = IngredientUpdate
  { name :: Maybe Text,
    createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime
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
