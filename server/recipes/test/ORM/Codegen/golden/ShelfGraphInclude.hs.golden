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

module Schema.ShelfGraphInclude
  ( ShelfGraphInclude (..),
    WithBooksTags (..),
    NoInclude (..),
    ResolveInclude,
    unwrapWithBooksTags,
    unwrapNoInclude,
    BookInclude (..),
    BookWithChapters (..),
    ShelfWithBooksTags (..)
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
import Schema.Tag (TagTable, TagRow (..))
import qualified Schema.Book as Book
import qualified Schema.Chapter as Chapter
import qualified Schema.Tag as Tag

newtype BookInclude = BookInclude
  { chapters :: Bool
  }
  deriving (Show, Eq)

data ShelfGraphInclude = ShelfGraphInclude
  { books :: Maybe BookInclude,
    tags :: Bool
  }
  deriving (Show, Eq)

data BookWithChapters = BookWithChapters
  { book :: BookRow,
    chapters :: [ChapterRow]
  }
  deriving (Show, Eq)

data ShelfWithBooksTags = ShelfWithBooksTags
  { shelf :: ShelfRow,
    books :: [BookWithChapters],
    tags :: [TagRow]
  }
  deriving (Show, Eq)


type family ResolveInclude preset :: Type
type instance ResolveInclude WithBooksTags = ShelfWithBooksTags
type instance ResolveInclude NoInclude = ShelfRow

newtype WithBooksTags = WithBooksTags ShelfGraphInclude
  deriving (Show, Eq)

newtype NoInclude = NoInclude ShelfGraphInclude
  deriving (Show, Eq)

unwrapWithBooksTags :: WithBooksTags -> ShelfGraphInclude
unwrapWithBooksTags (WithBooksTags include) = include

unwrapNoInclude :: NoInclude -> ShelfGraphInclude
unwrapNoInclude (NoInclude include) = include

instance IncludesJoin ShelfGraphInclude where
  includesJoin ShelfGraphInclude {books, tags} = isJust books || tags

instance NestInclude ShelfGraphInclude ShelfWithBooksTags where
  type RootRow ShelfGraphInclude = ShelfRow
  wrapRoot _ shelf = ShelfWithBooksTags {shelf, books = [], tags = []}

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

loadShelfGraphInclude :: ShelfGraphInclude -> [ShelfRow] -> Db [ShelfWithBooksTags]
loadShelfGraphInclude include roots = do
  booksMap <- case include.books of
    Nothing -> pure emptyGroups
    Just nestedInclude -> do
      rows <- findByIn @BookTable @BookRow Book.bookShelfId (map (.id) roots)
      nested <- loadBookInclude nestedInclude rows
      pure $ indexHasMany ((.shelfId) . (.book)) nested
  tagsMap <-
    if include.tags
      then indexHasMany (.shelfId) <$> findByIn @TagTable @TagRow Tag.tagShelfId (map (.id) roots)
      else pure emptyGroups
  pure
    [
      ShelfWithBooksTags {
        shelf = root,
        books = lookupGroups root.id booksMap,
        tags = lookupGroups root.id tagsMap
      }
    | root <- roots
    ]


instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable ShelfGraphInclude ShelfWithBooksTags where
  executeInclude include modifier = do
    roots <- findMany @ShelfTable @ShelfRow (prepareIncludeRootQuery @ShelfTable modifier)
    loadShelfGraphInclude include roots


