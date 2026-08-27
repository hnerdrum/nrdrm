{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Schema.ChapterInclude
  ( ChapterInclude (..),
    WithSections (..),
    NoInclude (..),
    ResolveInclude,
    unwrapWithSections,
    unwrapNoInclude,
    ChapterWithSections (..)
  )
where

import Data.Kind (Type)
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
import Schema.Chapter (ChapterTable, ChapterRow (..))
import Schema.Section (SectionTable, SectionRow (..))
import qualified Schema.Section as Section

newtype ChapterInclude = ChapterInclude
  { sections :: Bool
  }
  deriving (Show, Eq)

data ChapterWithSections = ChapterWithSections
  { chapter :: ChapterRow,
    sections :: [SectionRow]
  }
  deriving (Show, Eq)

type family ResolveInclude preset :: Type
type instance ResolveInclude WithSections = ChapterWithSections
type instance ResolveInclude NoInclude = ChapterRow

newtype WithSections = WithSections ChapterInclude
  deriving (Show, Eq)

newtype NoInclude = NoInclude ChapterInclude
  deriving (Show, Eq)

unwrapWithSections :: WithSections -> ChapterInclude
unwrapWithSections (WithSections include) = include

unwrapNoInclude :: NoInclude -> ChapterInclude
unwrapNoInclude (NoInclude include) = include

instance IncludesJoin ChapterInclude where
  includesJoin ChapterInclude {sections} = sections

instance NestInclude ChapterInclude ChapterWithSections where
  type RootRow ChapterInclude = ChapterRow
  wrapRoot _ chapter = ChapterWithSections {chapter, sections = []}

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

instance {-# OVERLAPPING #-} ExecuteInclude ChapterTable ChapterInclude ChapterWithSections where
  executeInclude include modifier = do
    roots <- findMany @ChapterTable @ChapterRow (prepareIncludeRootQuery @ChapterTable modifier)
    loadChapterInclude include roots

