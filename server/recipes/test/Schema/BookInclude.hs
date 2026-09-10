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

module Schema.BookInclude
  ( BookInclude (..),
    WithChapters (..),
    NoInclude (..),
    ResolveInclude,
    unwrapWithChapters,
    unwrapNoInclude,
    Chapters (..),
    unwrapChapters,
    BookWithChapter (..),
    ChapterInclude (..),
    ChapterWithSections (..),
    BookWithChapters (..)
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
import Schema.Book (BookTable, BookRow (..))
import Schema.Chapter (ChapterTable, ChapterRow (..))
import Schema.Section (SectionTable, SectionRow (..))
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

data BookWithChapter = BookWithChapter
  { book :: BookRow,
    chapters :: [ChapterRow]
  }
  deriving (Show, Eq)

type family ResolveInclude preset :: Type
type instance ResolveInclude WithChapters = BookWithChapters
type instance ResolveInclude NoInclude = BookRow
type instance ResolveInclude Chapters = BookWithChapter

newtype WithChapters = WithChapters BookInclude
  deriving (Show, Eq)

newtype NoInclude = NoInclude BookInclude
  deriving (Show, Eq)

unwrapWithChapters :: WithChapters -> BookInclude
unwrapWithChapters (WithChapters include) = include

unwrapNoInclude :: NoInclude -> BookInclude
unwrapNoInclude (NoInclude include) = include

newtype Chapters = Chapters BookInclude
  deriving (Show, Eq)

unwrapChapters :: Chapters -> BookInclude
unwrapChapters (Chapters include) = include

instance IncludesJoin BookInclude where
  includesJoin BookInclude {chapters} = isJust chapters

instance NestInclude BookInclude BookWithChapters where
  type RootRow BookInclude = BookRow
  wrapRoot _ book = BookWithChapters {book, chapters = []}

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

loadBookWithChapter :: BookInclude -> [BookRow] -> Db [BookWithChapter]
loadBookWithChapter include roots = do
  chaptersMap <- case include.chapters of
    Nothing -> pure emptyGroups
    Just _ ->
      indexHasMany (.bookRef) <$> findByIn @ChapterTable @ChapterRow Chapter.chapterBookRef (map (.id) roots)
  pure
    [
      BookWithChapter {
        book = root,
        chapters = lookupGroups root.id chaptersMap
      }
    | root <- roots
    ]

instance {-# OVERLAPPING #-} ExecuteInclude BookTable BookInclude BookWithChapters where
  executeInclude include modifier = do
    roots <- findMany @BookTable @BookRow (prepareIncludeRootQuery @BookTable modifier)
    loadBookInclude include roots

instance {-# OVERLAPPING #-} ExecuteInclude BookTable Chapters BookWithChapter where
  executeInclude (Chapters include) modifier = do
    roots <- findMany @BookTable @BookRow (prepareIncludeRootQuery @BookTable modifier)
    loadBookWithChapter include roots

instance {-# OVERLAPPING #-} ExecuteInclude BookTable WithChapters BookWithChapters where
  executeInclude (WithChapters include) modifier = executeInclude include modifier

