{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeApplications #-}

module Schema.Shelf
  ( ShelfTable (..),
    BookTable (..),
    ShelfRow (..),
    BookRow (..),
    ShelfCreate (..),
    BookCreate (..),
    shelfId,
    shelfName,
    bookId,
    bookShelfId,
    bookTitle,
    shelfBooks,
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

instance FromRow ShelfRow where
  fromRow = ShelfRow <$> field <*> field

instance FromRow BookRow where
  fromRow = BookRow <$> field <*> field <*> field

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

shelfBooks :: HasMany ShelfTable BookTable UUID
shelfBooks =
  HasMany
    { localKey = shelfId,
      foreignKey = bookShelfId,
      joinType = LeftJoin
    }
