{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module Schema.Book
  ( BookTable (..),
    BookRow (..),
    BookCreate (..),
    BookUpdate (..),
    bookId,
    bookShelfId,
    bookTitle,
    bookChapters
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import ORM.PG (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), emptyInsert, set, setMaybe)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe)
import ORM.Relation (HasMany (..), JoinType (..))
import Schema.Chapter (ChapterTable, chapterBookRef)

data BookTable = BookTable

type instance PrimaryKeyType BookTable = UUID

instance Entity BookTable where
  tableName = "test_book"
  primaryKey = bookId

instance Insertable BookTable where
  type CreateInput BookTable = BookCreate
  toInsertBuilder input =
    setMaybe bookId input.id $
      set bookShelfId input.shelfId $
      set bookTitle input.title $
      emptyInsert @BookTable


instance Updatable BookTable where
  type UpdateInput BookTable = BookUpdate
  updatedAtField = Nothing
  toUpdateBuilder input =
    setFieldMaybe bookShelfId input.shelfId $
      setFieldMaybe bookTitle input.title $
      emptyUpdate @BookTable


data BookRow = BookRow
  { id :: UUID,
    shelfId :: UUID,
    title :: Text
  }
  deriving (Show, Eq)


data BookCreate = BookCreate
  { id :: Maybe UUID,
    shelfId :: UUID,
    title :: Text
  }
  deriving (Show, Eq)


data BookUpdate = BookUpdate
  { shelfId :: Maybe UUID,
    title :: Maybe Text
  }
  deriving (Show, Eq)


instance FromRow BookRow where
  fromRow = BookRow <$> field <*> field <*> field


bookId :: Field BookTable UUID
bookId = Field "id" "id"

bookShelfId :: Field BookTable UUID
bookShelfId = Field "shelfId" "shelf_id"

bookTitle :: Field BookTable Text
bookTitle = Field "title" "title"

bookChapters :: HasMany BookTable ChapterTable UUID
bookChapters =
  HasMany
    { localKey = bookId,
      foreignKey = chapterBookRef,
      joinType = LeftJoin
    }

