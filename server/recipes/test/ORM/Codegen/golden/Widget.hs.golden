{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module Schema.Widget
  ( WidgetTable (..),
    WidgetRow (..),
    WidgetCreate (..),
    WidgetUpdate (..),
    widgetId,
    widgetCreatedAt,
    widgetUpdatedAt,
    widgetName,
    widgetDescription
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), emptyInsert, set, setMaybe, setNullable)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe, setFieldNullable)

data WidgetTable = WidgetTable

type instance PrimaryKeyType WidgetTable = UUID

instance Entity WidgetTable where
  tableName = "test_widget"
  primaryKey = widgetId

instance Insertable WidgetTable where
  type CreateInput WidgetTable = WidgetCreate
  toInsertBuilder input =
    setMaybe widgetId input.id $
      setMaybe widgetCreatedAt input.createdAt $
      setMaybe widgetUpdatedAt input.updatedAt $
      set widgetName input.name $
      setNullable widgetDescription input.description $
      emptyInsert @WidgetTable


instance Updatable WidgetTable where
  type UpdateInput WidgetTable = WidgetUpdate
  updatedAtField = Just widgetUpdatedAt
  toUpdateBuilder input =
    setFieldMaybe widgetCreatedAt input.createdAt $
      setFieldMaybe widgetUpdatedAt input.updatedAt $
      setFieldMaybe widgetName input.name $
      setFieldNullable widgetDescription input.description $
      emptyUpdate @WidgetTable


data WidgetRow = WidgetRow
  { id :: UUID,
    createdAt :: UTCTime,
    updatedAt :: UTCTime,
    name :: Text,
    description :: Maybe Text
  }
  deriving (Show, Eq)


data WidgetCreate = WidgetCreate
  { id :: Maybe UUID,
    createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
    name :: Text,
    description :: NullableValue Text
  }
  deriving (Show, Eq)


data WidgetUpdate = WidgetUpdate
  { createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
    name :: Maybe Text,
    description :: NullableValue Text
  }
  deriving (Show, Eq)


instance FromRow WidgetRow where
  fromRow = WidgetRow <$> field <*> field <*> field <*> field <*> field


widgetId :: Field WidgetTable UUID
widgetId = Field "id" "id"

widgetCreatedAt :: Field WidgetTable UTCTime
widgetCreatedAt = Field "createdAt" "created_at"

widgetUpdatedAt :: Field WidgetTable UTCTime
widgetUpdatedAt = Field "updatedAt" "updated_at"

widgetName :: Field WidgetTable Text
widgetName = Field "name" "name"

widgetDescription :: Field WidgetTable Text
widgetDescription = Field "description" "description"

