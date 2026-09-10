{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Schema.ShelfInclude
  ( ShelfInclude (..),
    WithBooks (..),
    NoInclude (..),
    ResolveInclude,
    unwrapWithBooks,
    unwrapNoInclude,
    Books (..),
    unwrapBooks,
    ShelfWithBook (..),
    BookInclude (..),
    BookWithChapters (..),
    ShelfWithBooks (..)
  )
where

import Data.Kind (Type)
import Data.Maybe (isJust)
import ORM.Db (Db)
import ORM.Include
  ( ExecuteInclude (..),
    IncludesJoin (..),
    NestInclude (..)
  )
import ORM.Operations (findMany)
import ORM.SelectIn
  ( findByIn,
    prepareIncludeRootQuery,
    emptyGroups,
    indexHasMany,
    lookupGroups
  )
import Schema.Shelf (ShelfTable, ShelfRow (..))
import Schema.Book (BookTable, BookRow (..))
import Schema.Chapter (ChapterTable, ChapterRow (..))
import qualified Schema.Book as Book
import qualified Schema.Chapter as Chapter

newtype BookInclude = BookInclude
  { chapters :: Bool
  }
  deriving (Show, Eq)

newtype ShelfInclude = ShelfInclude
  { books :: Maybe BookInclude
  }
  deriving (Show, Eq)

data BookWithChapters = BookWithChapters
  { book :: BookRow,
    chapters :: [ChapterRow]
  }
  deriving (Show, Eq)

data ShelfWithBooks = ShelfWithBooks
  { shelf :: ShelfRow,
    books :: [BookWithChapters]
  }
  deriving (Show, Eq)

data ShelfWithBook = ShelfWithBook
  { shelf :: ShelfRow,
    books :: [BookRow]
  }
  deriving (Show, Eq)

type family ResolveInclude preset :: Type
type instance ResolveInclude WithBooks = ShelfWithBooks
type instance ResolveInclude NoInclude = ShelfRow
type instance ResolveInclude Books = ShelfWithBook

newtype WithBooks = WithBooks ShelfInclude
  deriving (Show, Eq)

newtype NoInclude = NoInclude ShelfInclude
  deriving (Show, Eq)

unwrapWithBooks :: WithBooks -> ShelfInclude
unwrapWithBooks (WithBooks include) = include

unwrapNoInclude :: NoInclude -> ShelfInclude
unwrapNoInclude (NoInclude include) = include

newtype Books = Books ShelfInclude
  deriving (Show, Eq)

unwrapBooks :: Books -> ShelfInclude
unwrapBooks (Books include) = include

instance IncludesJoin ShelfInclude where
  includesJoin ShelfInclude {books} = isJust books

instance NestInclude ShelfInclude ShelfWithBooks where
  type RootRow ShelfInclude = ShelfRow
  wrapRoot _ shelf = ShelfWithBooks {shelf, books = []}

loadBookInclude :: BookInclude -> [BookRow] -> Db [BookWithChapters]
loadBookInclude include roots = do
  chaptersMap <-
    if include.chapters
      then indexHasMany (.bookRef) <$> findByIn @ChapterTable @ChapterRow Chapter.chapterBookRef (map (.id) roots)
      else pure emptyGroups
  pure
    [
      BookWithChapters {
        book = root,
        chapters = lookupGroups root.id chaptersMap
      }
    | root <- roots
    ]

loadShelfInclude :: ShelfInclude -> [ShelfRow] -> Db [ShelfWithBooks]
loadShelfInclude include roots = do
  booksMap <- case include.books of
    Nothing -> pure emptyGroups
    Just nestedInclude -> do
      rows <- findByIn @BookTable @BookRow Book.bookShelfId (map (.id) roots)
      nested <- loadBookInclude nestedInclude rows
      pure $ indexHasMany ((.shelfId) . (.book)) nested
  pure
    [
      ShelfWithBooks {
        shelf = root,
        books = lookupGroups root.id booksMap
      }
    | root <- roots
    ]

loadShelfWithBook :: ShelfInclude -> [ShelfRow] -> Db [ShelfWithBook]
loadShelfWithBook include roots = do
  booksMap <- case include.books of
    Nothing -> pure emptyGroups
    Just _ ->
      indexHasMany (.shelfId) <$> findByIn @BookTable @BookRow Book.bookShelfId (map (.id) roots)
  pure
    [
      ShelfWithBook {
        shelf = root,
        books = lookupGroups root.id booksMap
      }
    | root <- roots
    ]

instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable ShelfInclude ShelfWithBooks where
  executeInclude include modifier = do
    roots <- findMany @ShelfTable @ShelfRow (prepareIncludeRootQuery @ShelfTable modifier)
    loadShelfInclude include roots

instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable Books ShelfWithBook where
  executeInclude (Books include) modifier = do
    roots <- findMany @ShelfTable @ShelfRow (prepareIncludeRootQuery @ShelfTable modifier)
    loadShelfWithBook include roots

instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable WithBooks ShelfWithBooks where
  executeInclude (WithBooks include) modifier = executeInclude include modifier

