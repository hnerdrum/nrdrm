{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module Schema.Chapter
  ( ChapterTable (..),
    ChapterRow (..),
    ChapterCreate (..),
    ChapterUpdate (..),
    chapterId,
    chapterBookRef,
    chapterHeading
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), emptyInsert, set, setMaybe)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe)

data ChapterTable = ChapterTable

type instance PrimaryKeyType ChapterTable = UUID

instance Entity ChapterTable where
  tableName = "test_chapter"
  primaryKey = chapterId

instance Insertable ChapterTable where
  type CreateInput ChapterTable = ChapterCreate
  toInsertBuilder input =
    setMaybe chapterId input.id $
      set chapterBookRef input.bookRef $
      set chapterHeading input.heading $
      emptyInsert @ChapterTable


instance Updatable ChapterTable where
  type UpdateInput ChapterTable = ChapterUpdate
  updatedAtField = Nothing
  toUpdateBuilder input =
    setFieldMaybe chapterBookRef input.bookRef $
      setFieldMaybe chapterHeading input.heading $
      emptyUpdate @ChapterTable


data ChapterRow = ChapterRow
  { id :: UUID,
    bookRef :: UUID,
    heading :: Text
  }
  deriving (Show, Eq)


data ChapterCreate = ChapterCreate
  { id :: Maybe UUID,
    bookRef :: UUID,
    heading :: Text
  }
  deriving (Show, Eq)


data ChapterUpdate = ChapterUpdate
  { bookRef :: Maybe UUID,
    heading :: Maybe Text
  }
  deriving (Show, Eq)


instance FromRow ChapterRow where
  fromRow = ChapterRow <$> field <*> field <*> field


chapterId :: Field ChapterTable UUID
chapterId = Field "id" "id"

chapterBookRef :: Field ChapterTable UUID
chapterBookRef = Field "bookRef" "book_id"

chapterHeading :: Field ChapterTable Text
chapterHeading = Field "heading" "heading"

