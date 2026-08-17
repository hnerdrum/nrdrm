{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Schema.ShelfDeepInclude
  ( ShelfDeepInclude (..),
    WithBooks (..),
    NoInclude (..),
    ResolveInclude,
    unwrapWithBooks,
    unwrapNoInclude,
    ChapterInclude (..),
    BookInclude (..),
    ChapterWithSections (..),
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
import Schema.Section (SectionTable, SectionRow (..))
import qualified Schema.Book as Book
import qualified Schema.Chapter as Chapter
import qualified Schema.Section as Section

newtype ChapterInclude = ChapterInclude
  { sections :: Bool
  }
  deriving (Show, Eq)

newtype BookInclude = BookInclude
  { chapters :: Maybe ChapterInclude
  }
  deriving (Show, Eq)

newtype ShelfDeepInclude = ShelfDeepInclude
  { books :: Maybe BookInclude
  }
  deriving (Show, Eq)

data ChapterWithSections = ChapterWithSections
  { chapter :: ChapterRow,
    sections :: [SectionRow]
  }
  deriving (Show, Eq)

data BookWithChapters = BookWithChapters
  { book :: BookRow,
    chapters :: [ChapterWithSections]
  }
  deriving (Show, Eq)

data ShelfWithBooks = ShelfWithBooks
  { shelf :: ShelfRow,
    books :: [BookWithChapters]
  }
  deriving (Show, Eq)

type family ResolveInclude preset :: Type
type instance ResolveInclude WithBooks = ShelfWithBooks
type instance ResolveInclude NoInclude = ShelfRow

newtype WithBooks = WithBooks ShelfDeepInclude
  deriving (Show, Eq)

newtype NoInclude = NoInclude ShelfDeepInclude
  deriving (Show, Eq)

unwrapWithBooks :: WithBooks -> ShelfDeepInclude
unwrapWithBooks (WithBooks include) = include

unwrapNoInclude :: NoInclude -> ShelfDeepInclude
unwrapNoInclude (NoInclude include) = include

instance IncludesJoin ShelfDeepInclude where
  includesJoin ShelfDeepInclude {books} = isJust books

instance NestInclude ShelfDeepInclude ShelfWithBooks where
  type RootRow ShelfDeepInclude = ShelfRow
  wrapRoot _ shelf = ShelfWithBooks {shelf, books = []}

loadChapterInclude :: ChapterInclude -> [ChapterRow] -> Db [ChapterWithSections]
loadChapterInclude include roots = do
  sectionsMap <-
    if include.sections
      then indexHasMany (.chapterRef) <$> findByIn @SectionTable @SectionRow Section.sectionChapterRef (map (.id) roots)
      else pure emptyGroups
  pure
    [
      ChapterWithSections {
        chapter = root,
        sections = lookupGroups root.id sectionsMap
      }
    | root <- roots
    ]

loadBookInclude :: BookInclude -> [BookRow] -> Db [BookWithChapters]
loadBookInclude include roots = do
  chaptersMap <- case include.chapters of
    Nothing -> pure emptyGroups
    Just nestedInclude -> do
      rows <- findByIn @ChapterTable @ChapterRow Chapter.chapterBookRef (map (.id) roots)
      nested <- loadChapterInclude nestedInclude rows
      pure $ indexHasMany ((.bookRef) . (.chapter)) nested
  pure
    [
      BookWithChapters {
        book = root,
        chapters = lookupGroups root.id chaptersMap
      }
    | root <- roots
    ]

loadShelfDeepInclude :: ShelfDeepInclude -> [ShelfRow] -> Db [ShelfWithBooks]
loadShelfDeepInclude include roots = do
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

instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable ShelfDeepInclude ShelfWithBooks where
  executeInclude include modifier = do
    roots <- findMany @ShelfTable @ShelfRow (prepareIncludeRootQuery @ShelfTable modifier)
    loadShelfDeepInclude include roots

