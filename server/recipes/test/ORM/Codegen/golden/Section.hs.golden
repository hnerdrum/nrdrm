{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module Schema.Section
  ( SectionTable (..),
    SectionRow (..),
    SectionCreate (..),
    SectionUpdate (..),
    sectionId,
    sectionChapterRef,
    sectionLabel
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import ORM.PG (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), emptyInsert, set, setMaybe)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe)

data SectionTable = SectionTable

type instance PrimaryKeyType SectionTable = UUID

instance Entity SectionTable where
  tableName = "test_section"
  primaryKey = sectionId

instance Insertable SectionTable where
  type CreateInput SectionTable = SectionCreate
  toInsertBuilder input =
    setMaybe sectionId input.id $
      set sectionChapterRef input.chapterRef $
      set sectionLabel input.label $
      emptyInsert @SectionTable


instance Updatable SectionTable where
  type UpdateInput SectionTable = SectionUpdate
  updatedAtField = Nothing
  toUpdateBuilder input =
    setFieldMaybe sectionChapterRef input.chapterRef $
      setFieldMaybe sectionLabel input.label $
      emptyUpdate @SectionTable


data SectionRow = SectionRow
  { id :: UUID,
    chapterRef :: UUID,
    label :: Text
  }
  deriving (Show, Eq)


data SectionCreate = SectionCreate
  { id :: Maybe UUID,
    chapterRef :: UUID,
    label :: Text
  }
  deriving (Show, Eq)


data SectionUpdate = SectionUpdate
  { chapterRef :: Maybe UUID,
    label :: Maybe Text
  }
  deriving (Show, Eq)


instance FromRow SectionRow where
  fromRow = SectionRow <$> field <*> field <*> field


sectionId :: Field SectionTable UUID
sectionId = Field "id" "id"

sectionChapterRef :: Field SectionTable UUID
sectionChapterRef = Field "chapterRef" "chapter_id"

sectionLabel :: Field SectionTable Text
sectionLabel = Field "label" "label"

