{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module Schema.Tag
  ( TagTable (..),
    TagRow (..),
    TagCreate (..),
    TagUpdate (..),
    tagId,
    tagShelfId,
    tagLabel
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import ORM.PG (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), emptyInsert, set, setMaybe)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe)

data TagTable = TagTable

type instance PrimaryKeyType TagTable = UUID

instance Entity TagTable where
  tableName = "test_tag"
  primaryKey = tagId

instance Insertable TagTable where
  type CreateInput TagTable = TagCreate
  toInsertBuilder input =
    setMaybe tagId input.id $
      set tagShelfId input.shelfId $
      set tagLabel input.label $
      emptyInsert @TagTable


instance Updatable TagTable where
  type UpdateInput TagTable = TagUpdate
  updatedAtField = Nothing
  toUpdateBuilder input =
    setFieldMaybe tagShelfId input.shelfId $
      setFieldMaybe tagLabel input.label $
      emptyUpdate @TagTable


data TagRow = TagRow
  { id :: UUID,
    shelfId :: UUID,
    label :: Text
  }
  deriving (Show, Eq)


data TagCreate = TagCreate
  { id :: Maybe UUID,
    shelfId :: UUID,
    label :: Text
  }
  deriving (Show, Eq)


data TagUpdate = TagUpdate
  { shelfId :: Maybe UUID,
    label :: Maybe Text
  }
  deriving (Show, Eq)


instance FromRow TagRow where
  fromRow = TagRow <$> field <*> field <*> field


tagId :: Field TagTable UUID
tagId = Field "id" "id"

tagShelfId :: Field TagTable UUID
tagShelfId = Field "shelfId" "shelf_id"

tagLabel :: Field TagTable Text
tagLabel = Field "label" "label"

