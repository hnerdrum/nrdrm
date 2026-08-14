{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Schema.Ingredient
  ( IngredientTable (..),
    IngredientRow (..),
    IngredientCreate (..),
    IngredientUpdate (..),
    ingredientId,
    ingredientCreatedAt,
    ingredientUpdatedAt,
    ingredientName
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), emptyInsert, set, setMaybe)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe)

data IngredientTable = IngredientTable

type instance PrimaryKeyType IngredientTable = UUID

instance Entity IngredientTable where
  tableName = "ingredient"
  primaryKey = ingredientId

instance Insertable IngredientTable where
  type CreateInput IngredientTable = IngredientCreate
  toInsertBuilder input =
    setMaybe ingredientId input.id $
      setMaybe ingredientCreatedAt input.createdAt $
      setMaybe ingredientUpdatedAt input.updatedAt $
      set ingredientName input.name $
      emptyInsert @IngredientTable


instance Updatable IngredientTable where
  type UpdateInput IngredientTable = IngredientUpdate
  updatedAtField = Just ingredientUpdatedAt
  toUpdateBuilder input =
    setFieldMaybe ingredientCreatedAt input.createdAt $
      setFieldMaybe ingredientUpdatedAt input.updatedAt $
      setFieldMaybe ingredientName input.name $
      emptyUpdate @IngredientTable


data IngredientRow = IngredientRow
  { id :: UUID,
    createdAt :: UTCTime,
    updatedAt :: UTCTime,
    name :: Text
  }
  deriving (Show, Eq)


data IngredientCreate = IngredientCreate
  { id :: Maybe UUID,
    createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
    name :: Text
  }
  deriving (Show, Eq)


data IngredientUpdate = IngredientUpdate
  { createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
    name :: Maybe Text
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

