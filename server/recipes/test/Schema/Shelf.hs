{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeApplications #-}

module Schema.Shelf
  ( ShelfTable (..),
    BookTable (..),
    ChapterTable (..),
    ShelfRow (..),
    BookRow (..),
    ChapterRow (..),
    ShelfCreate (..),
    BookCreate (..),
    ChapterCreate (..),
    shelfId,
    shelfName,
    bookId,
    bookShelfId,
    bookTitle,
    chapterId,
    chapterBookRef,
    chapterHeading,
    shelfBooks,
    bookChapters,
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), set, setMaybe, setValue)
import ORM.Relation (HasMany (..), JoinType (..))

data ShelfTable = ShelfTable

type instance PrimaryKeyType ShelfTable = UUID

instance Entity ShelfTable where
  tableName = "test_shelf"
  primaryKey = shelfId

instance Insertable ShelfTable where
  type CreateInput ShelfTable = ShelfCreate
  toInsertBuilder input =
    setMaybe shelfId input.id $
      setValue shelfName input.name

data BookTable = BookTable

type instance PrimaryKeyType BookTable = UUID

instance Entity BookTable where
  tableName = "test_book"
  primaryKey = bookId

instance Insertable BookTable where
  type CreateInput BookTable = BookCreate
  toInsertBuilder input =
    setMaybe bookId input.id $
      set bookShelfId input.shelfRef $
        setValue bookTitle input.title

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
        setValue chapterHeading input.heading

data ShelfRow = ShelfRow
  { id :: UUID,
    name :: Text
  }
  deriving (Show, Eq)

data BookRow = BookRow
  { id :: UUID,
    shelfRef :: UUID,
    title :: Text
  }
  deriving (Show, Eq)

data ChapterRow = ChapterRow
  { id :: UUID,
    bookRef :: UUID,
    heading :: Text
  }
  deriving (Show, Eq)

data ShelfCreate = ShelfCreate
  { id :: Maybe UUID,
    name :: Text
  }
  deriving (Show, Eq)

data BookCreate = BookCreate
  { id :: Maybe UUID,
    shelfRef :: UUID,
    title :: Text
  }
  deriving (Show, Eq)

data ChapterCreate = ChapterCreate
  { id :: Maybe UUID,
    bookRef :: UUID,
    heading :: Text
  }
  deriving (Show, Eq)

instance FromRow ShelfRow where
  fromRow = ShelfRow <$> field <*> field

instance FromRow BookRow where
  fromRow = BookRow <$> field <*> field <*> field

instance FromRow ChapterRow where
  fromRow = ChapterRow <$> field <*> field <*> field

shelfId :: Field ShelfTable UUID
shelfId = Field "id" "id"

shelfName :: Field ShelfTable Text
shelfName = Field "name" "name"

bookId :: Field BookTable UUID
bookId = Field "id" "id"

bookShelfId :: Field BookTable UUID
bookShelfId = Field "shelfId" "shelf_id"

bookTitle :: Field BookTable Text
bookTitle = Field "title" "title"

chapterId :: Field ChapterTable UUID
chapterId = Field "id" "id"

chapterBookRef :: Field ChapterTable UUID
chapterBookRef = Field "bookRef" "book_id"

chapterHeading :: Field ChapterTable Text
chapterHeading = Field "heading" "heading"

shelfBooks :: HasMany ShelfTable BookTable UUID
shelfBooks =
  HasMany
    { localKey = shelfId,
      foreignKey = bookShelfId,
      joinType = LeftJoin
    }

bookChapters :: HasMany BookTable ChapterTable UUID
bookChapters =
  HasMany
    { localKey = bookId,
      foreignKey = chapterBookRef,
      joinType = LeftJoin
    }
