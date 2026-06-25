{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module ORM.Schema.Recipe
  ( RecipeTable (..),
    RecipeRow (..),
    RecipeCreate (..),
    RecipeUpdate (..),
    recipeId,
    recipeCreatedAt,
    recipeUpdatedAt,
    recipeName,
    recipeDescription,
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), setMaybe, setNullable, setValue)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe, setFieldNullable)

data RecipeTable = RecipeTable

type instance PrimaryKeyType RecipeTable = UUID

instance Entity RecipeTable where
  tableName = "recipe"
  primaryKey = recipeId

instance Insertable RecipeTable where
  type CreateInput RecipeTable = RecipeCreate
  toInsertBuilder input =
    setNullable recipeDescription input.description $
      setMaybe recipeUpdatedAt input.updatedAt $
        setMaybe recipeCreatedAt input.createdAt $
          setMaybe recipeId input.id $
            setValue recipeName input.name

instance Updatable RecipeTable where
  type UpdateInput RecipeTable = RecipeUpdate
  updatedAtField = Just recipeUpdatedAt
  toUpdateBuilder input =
    setFieldNullable recipeDescription input.description $
      setFieldMaybe recipeUpdatedAt input.updatedAt $
        setFieldMaybe recipeCreatedAt input.createdAt $
          setFieldMaybe recipeName input.name (emptyUpdate @RecipeTable)

data RecipeRow = RecipeRow
  { id :: UUID,
    createdAt :: UTCTime,
    updatedAt :: UTCTime,
    name :: Text,
    description :: Maybe Text
  }
  deriving (Show)

data RecipeCreate = RecipeCreate
  { id :: Maybe UUID,
    createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
    name :: Text,
    description :: NullableValue Text
  }
  deriving (Show, Eq)

data RecipeUpdate = RecipeUpdate
  { name :: Maybe Text,
    createdAt :: Maybe UTCTime,
    updatedAt :: Maybe UTCTime,
    description :: NullableValue Text
  }
  deriving (Show, Eq)

instance FromRow RecipeRow where
  fromRow = RecipeRow <$> field <*> field <*> field <*> field <*> field

recipeId :: Field RecipeTable UUID
recipeId = Field "id" "id"

recipeCreatedAt :: Field RecipeTable UTCTime
recipeCreatedAt = Field "createdAt" "created_at"

recipeUpdatedAt :: Field RecipeTable UTCTime
recipeUpdatedAt = Field "updatedAt" "updated_at"

recipeName :: Field RecipeTable Text
recipeName = Field "name" "name"

recipeDescription :: Field RecipeTable Text
recipeDescription = Field "description" "description"
