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
    ChapterInclude (..),
    BookInclude (..),
    ChapterWithSections (..),
    BookWithChapters (..),
    ShelfWithBooks (..),
    ShelfBookJoinRow (..),
    ShelfBookChapterJoinRow (..),
    ShelfBookChapterSectionJoinRow (..)
  )
where

import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Group (groupByKey)
import ORM.Include
  ( BuildJoinChain (..),
    ExecuteInclude (..),
    IncludesJoin (..),
    NestInclude (..),
    applyRootFilter,
  )
import qualified ORM.JoinChain as JoinChain
import ORM.Operations (findManyConn)
import Schema.Shelf (ShelfTable, ShelfRow (..), shelfBooks)
import Schema.Book (BookRow (..), bookChapters)
import Schema.Chapter (ChapterRow (..), chapterSections)
import Schema.Section (SectionRow (..))
import qualified Schema.Shelf as Shelf
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

instance IncludesJoin ShelfDeepInclude where
  includesJoin ShelfDeepInclude {books} = isJust books

data ShelfBookJoinRow = ShelfBookJoinRow
  { shelfId :: UUID,
    shelfName :: Text,
    bookId :: Maybe UUID,
    bookTitle :: Maybe Text
  }
  deriving (Show, Eq)

instance FromRow ShelfBookJoinRow where
  fromRow = ShelfBookJoinRow <$> field <*> field <*> field <*> field

shelfBookColumns :: [Text]
shelfBookColumns =
  [ JoinChain.col "s" Shelf.shelfId,
    JoinChain.col "s" Shelf.shelfName,
    JoinChain.col "b" Book.bookId,
    JoinChain.col "b" Book.bookTitle
  ]

buildShelfBookJoin :: JoinChain.JoinChain ShelfTable
buildShelfBookJoin =
  JoinChain.selectColumns shelfBookColumns $
    JoinChain.buildJoinChainFromHasMany shelfBooks "s" "b"

data ShelfBookChapterJoinRow = ShelfBookChapterJoinRow
  { shelfId :: UUID,
    shelfName :: Text,
    bookId :: Maybe UUID,
    bookTitle :: Maybe Text,
    chapterId :: Maybe UUID,
    chapterHeading :: Maybe Text
  }
  deriving (Show, Eq)

instance FromRow ShelfBookChapterJoinRow where
  fromRow = ShelfBookChapterJoinRow <$> field <*> field <*> field <*> field <*> field <*> field

shelfBookChapterColumns :: [Text]
shelfBookChapterColumns =
  shelfBookColumns
    ++ [ JoinChain.col "c" Chapter.chapterId,
         JoinChain.col "c" Chapter.chapterHeading
       ]

buildShelfBookChapterJoin :: JoinChain.JoinChain ShelfTable
buildShelfBookChapterJoin =
  JoinChain.selectColumns shelfBookChapterColumns $
    JoinChain.addHasManyJoin bookChapters "b" "c" buildShelfBookJoin

data ShelfBookChapterSectionJoinRow = ShelfBookChapterSectionJoinRow
  { shelfId :: UUID,
    shelfName :: Text,
    bookId :: Maybe UUID,
    bookTitle :: Maybe Text,
    chapterId :: Maybe UUID,
    chapterHeading :: Maybe Text,
    sectionId :: Maybe UUID,
    sectionLabel :: Maybe Text
  }
  deriving (Show, Eq)

instance FromRow ShelfBookChapterSectionJoinRow where
  fromRow = ShelfBookChapterSectionJoinRow <$> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field

shelfBookChapterSectionColumns :: [Text]
shelfBookChapterSectionColumns =
  shelfBookChapterColumns
    ++ [ JoinChain.col "se" Section.sectionId,
         JoinChain.col "se" Section.sectionLabel
       ]

buildShelfBookChapterSectionJoin :: JoinChain.JoinChain ShelfTable
buildShelfBookChapterSectionJoin =
  JoinChain.selectColumns shelfBookChapterSectionColumns $
    JoinChain.addHasManyJoin chapterSections "c" "se" buildShelfBookChapterJoin

instance BuildJoinChain ShelfTable ShelfDeepInclude where
  type JoinFlatRow ShelfDeepInclude = ShelfBookJoinRow
  buildJoinChain ShelfDeepInclude {books = Just BookInclude {chapters = Just ChapterInclude {sections = False}}} =
    buildShelfBookJoin
  buildJoinChain ShelfDeepInclude {books = Just BookInclude {chapters = Just ChapterInclude {sections = False}}} =
    buildShelfBookChapterJoin
  buildJoinChain ShelfDeepInclude {books = Just BookInclude {chapters = Just ChapterInclude {sections = True}}} =
    buildShelfBookChapterSectionJoin
  buildJoinChain ShelfDeepInclude {books = Nothing} =
    buildShelfBookJoin

instance NestInclude ShelfDeepInclude ShelfWithBooks where
  type RootRow ShelfDeepInclude = ShelfRow
  nestRows _ = nestShelfRows
  wrapRoot _ shelf = ShelfWithBooks {shelf, books = []}

nestShelfRows :: [ShelfBookJoinRow] -> [ShelfWithBooks]
nestShelfRows =
  map shelfWithBooksFromGroup . groupByKey (.shelfId)

shelfWithBooksFromGroup :: [ShelfBookJoinRow] -> ShelfWithBooks
shelfWithBooksFromGroup rows@(firstRow : _) =
  ShelfWithBooks
    { shelf = toShelfRow firstRow,
      books = map bookWithNoChapters $ mapMaybe toBookRow rows
    }
shelfWithBooksFromGroup [] =
  error "shelfWithBooksFromGroup: empty group"

bookWithNoChapters :: BookRow -> BookWithChapters
bookWithNoChapters book = BookWithChapters {book, chapters = []}

toShelfRow :: ShelfBookJoinRow -> ShelfRow
toShelfRow row = ShelfRow {id = row.shelfId, name = row.shelfName}

toBookRow :: ShelfBookJoinRow -> Maybe BookRow
toBookRow row
  | Just bid <- row.bookId,
    Just title <- row.bookTitle =
      Just BookRow {id = bid, title = title, shelfId = row.shelfId}
  | otherwise = Nothing

nestShelfBookChapterRows :: [ShelfBookChapterJoinRow] -> [ShelfWithBooks]
nestShelfBookChapterRows =
  map shelfWithChaptersFromShelfGroup . groupByKey (.shelfId)

shelfWithChaptersFromShelfGroup :: [ShelfBookChapterJoinRow] -> ShelfWithBooks
shelfWithChaptersFromShelfGroup rows@(firstRow : _) =
  ShelfWithBooks
    { shelf = toShelfRowFromChapter firstRow,
      books = mapMaybe bookWithChaptersFromGroup $ groupByKey (.bookId) rows
    }
shelfWithChaptersFromShelfGroup [] =
  error "shelfWithChaptersFromShelfGroup: empty group"

bookWithChaptersFromGroup :: [ShelfBookChapterJoinRow] -> Maybe BookWithChapters
bookWithChaptersFromGroup rows@(firstRow : _)
  | Just _ <- firstRow.bookId =
      Just
        BookWithChapters
          { book = toBookRowFromChapter firstRow,
            chapters = map chapterWithNoSections $ mapMaybe toChapterRow rows
          }
  | otherwise = Nothing
bookWithChaptersFromGroup [] = Nothing

chapterWithNoSections :: ChapterRow -> ChapterWithSections
chapterWithNoSections chapter = ChapterWithSections {chapter, sections = []}

toShelfRowFromChapter :: ShelfBookChapterJoinRow -> ShelfRow
toShelfRowFromChapter row = ShelfRow {id = row.shelfId, name = row.shelfName}

toBookRowFromChapter :: ShelfBookChapterJoinRow -> BookRow
toBookRowFromChapter row =
  BookRow
    { id = fromMaybe (error "toBookRowFromChapter: missing id") row.bookId,
      title = fromMaybe (error "toBookRowFromChapter: missing title") row.bookTitle,
      shelfId = row.shelfId
    }

toChapterRow :: ShelfBookChapterJoinRow -> Maybe ChapterRow
toChapterRow row
  | Just cid <- row.chapterId,
    Just heading <- row.chapterHeading,
    Just bid <- row.bookId =
      Just ChapterRow {id = cid, heading = heading, bookRef = bid}
  | otherwise = Nothing

nestShelfBookChapterSectionRows :: [ShelfBookChapterSectionJoinRow] -> [ShelfWithBooks]
nestShelfBookChapterSectionRows =
  map shelfWithChaptersSectionsFromShelfGroup . groupByKey (.shelfId)

shelfWithChaptersSectionsFromShelfGroup :: [ShelfBookChapterSectionJoinRow] -> ShelfWithBooks
shelfWithChaptersSectionsFromShelfGroup rows@(firstRow : _) =
  ShelfWithBooks
    { shelf = toShelfRowFromSection firstRow,
      books = mapMaybe bookWithChaptersFromSectionGroup $ groupByKey (.bookId) rows
    }
shelfWithChaptersSectionsFromShelfGroup [] =
  error "shelfWithChaptersSectionsFromShelfGroup: empty group"

bookWithChaptersFromSectionGroup :: [ShelfBookChapterSectionJoinRow] -> Maybe BookWithChapters
bookWithChaptersFromSectionGroup rows@(firstRow : _)
  | Just _ <- firstRow.bookId =
      Just
        BookWithChapters
          { book = toBookRowFromSection firstRow,
            chapters = mapMaybe chapterWithSectionsFromSectionGroup $ groupByKey (.chapterId) rows
          }
  | otherwise = Nothing
bookWithChaptersFromSectionGroup [] = Nothing

chapterWithSectionsFromSectionGroup :: [ShelfBookChapterSectionJoinRow] -> Maybe ChapterWithSections
chapterWithSectionsFromSectionGroup rows@(firstRow : _)
  | Just _ <- firstRow.chapterId =
      Just
        ChapterWithSections
          { chapter = toChapterRowFromSection firstRow,
            sections = mapMaybe toSectionRow rows
          }
  | otherwise = Nothing
chapterWithSectionsFromSectionGroup [] = Nothing

toShelfRowFromSection :: ShelfBookChapterSectionJoinRow -> ShelfRow
toShelfRowFromSection row = ShelfRow {id = row.shelfId, name = row.shelfName}

toBookRowFromSection :: ShelfBookChapterSectionJoinRow -> BookRow
toBookRowFromSection row =
  BookRow
    { id = fromMaybe (error "toBookRowFromSection: missing id") row.bookId,
      title = fromMaybe (error "toBookRowFromSection: missing title") row.bookTitle,
      shelfId = row.shelfId
    }

toChapterRowFromSection :: ShelfBookChapterSectionJoinRow -> ChapterRow
toChapterRowFromSection row =
  ChapterRow
    { id = fromMaybe (error "toChapterRowFromSection: missing id") row.chapterId,
      heading = fromMaybe (error "toChapterRowFromSection: missing heading") row.chapterHeading,
      bookRef = fromMaybe (error "toChapterRowFromSection: missing bookRef") row.bookId
    }

toSectionRow :: ShelfBookChapterSectionJoinRow -> Maybe SectionRow
toSectionRow row
  | Just sid <- row.sectionId,
    Just label <- row.sectionLabel,
    Just cid <- row.chapterId =
      Just SectionRow {id = sid, label = label, chapterRef = cid}
  | otherwise = Nothing

instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable ShelfDeepInclude ShelfWithBooks where
  executeInclude conn include modifier =
    case include.books of
      Nothing -> do
        roots <- findManyConn @ShelfTable @ShelfRow conn modifier
        pure $ map (wrapRoot include) roots
      Just BookInclude {chapters = Just ChapterInclude {sections = False}} -> do
        let chain = applyRootFilter buildShelfBookJoin modifier
        flatRows <- JoinChain.runJoinChainConn @ShelfBookJoinRow conn chain
        pure $ nestShelfRows flatRows
      Just BookInclude {chapters = Just ChapterInclude {sections = False}} -> do
        let chain = applyRootFilter buildShelfBookChapterJoin modifier
        flatRows <- JoinChain.runJoinChainConn @ShelfBookChapterJoinRow conn chain
        pure $ nestShelfBookChapterRows flatRows
      Just BookInclude {chapters = Just ChapterInclude {sections = True}} -> do
        let chain = applyRootFilter buildShelfBookChapterSectionJoin modifier
        flatRows <- JoinChain.runJoinChainConn @ShelfBookChapterSectionJoinRow conn chain
        pure $ nestShelfBookChapterSectionRows flatRows

