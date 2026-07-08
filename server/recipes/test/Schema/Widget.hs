{-# LANGUAGE AllowAmbiguousTypes #-}

module Schema.Widget
  ( WidgetTable (..),
    WidgetRow (..),
    WidgetCreate (..),
    WidgetUpdate (..),
    widgetId,
    widgetCreatedAt,
    widgetUpdatedAt,
    widgetName,
    widgetDescription,
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), setMaybe, setNullable, setValue)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe, setFieldNullable)

data WidgetTable = WidgetTable

type instance PrimaryKeyType WidgetTable = UUID

instance Entity WidgetTable where
  tableName = "test_widget"
  primaryKey = widgetId

instance Insertable WidgetTable where
  type CreateInput WidgetTable = WidgetCreate
  toInsertBuilder input =
    let WidgetCreate {id = wid, createdAt, updatedAt, name, description} = input
     in setNullable widgetDescription description $
          setMaybe widgetUpdatedAt updatedAt $
            setMaybe widgetCreatedAt createdAt $
              setMaybe widgetId wid $
                setValue widgetName name

instance Updatable WidgetTable where
  type UpdateInput WidgetTable = WidgetUpdate
  updatedAtField = Just widgetUpdatedAt
  toUpdateBuilder input =
    let WidgetUpdate {name, createdAt, updatedAt, description} = input
     in setFieldNullable widgetDescription description $
          setFieldMaybe widgetUpdatedAt updatedAt $
            setFieldMaybe widgetCreatedAt createdAt $
              setFieldMaybe widgetName name (emptyUpdate @WidgetTable)

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
  { name :: Maybe Text,
    createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
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
