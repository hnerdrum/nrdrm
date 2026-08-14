{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Schema.ShelfInclude
  ( ShelfInclude (..),
    BookInclude (..),
    BookWithChapters (..),
    ShelfWithBooks (..),
    ShelfBookJoinRow (..),
    ShelfBookChapterJoinRow (..)
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
import Schema.Chapter (ChapterRow (..))
import qualified Schema.Shelf as Shelf
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

instance IncludesJoin ShelfInclude where
  includesJoin ShelfInclude {books} = isJust books

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

instance BuildJoinChain ShelfTable ShelfInclude where
  type JoinFlatRow ShelfInclude = ShelfBookJoinRow
  buildJoinChain ShelfInclude {books = Just BookInclude {chapters = False}} =
    buildShelfBookJoin
  buildJoinChain ShelfInclude {books = Just BookInclude {chapters = True}} =
    buildShelfBookChapterJoin
  buildJoinChain ShelfInclude {books = Nothing} =
    buildShelfBookJoin

instance NestInclude ShelfInclude ShelfWithBooks where
  type RootRow ShelfInclude = ShelfRow
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
            chapters = mapMaybe toChapterRow rows
          }
  | otherwise = Nothing
bookWithChaptersFromGroup [] = Nothing

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

instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable ShelfInclude ShelfWithBooks where
  executeInclude conn include modifier =
    case include.books of
      Nothing -> do
        roots <- findManyConn @ShelfTable @ShelfRow conn modifier
        pure $ map (wrapRoot include) roots
      Just BookInclude {chapters = False} -> do
        let chain = applyRootFilter buildShelfBookJoin modifier
        flatRows <- JoinChain.runJoinChainConn @ShelfBookJoinRow conn chain
        pure $ nestShelfRows flatRows
      Just BookInclude {chapters = True} -> do
        let chain = applyRootFilter buildShelfBookChapterJoin modifier
        flatRows <- JoinChain.runJoinChainConn @ShelfBookChapterJoinRow conn chain
        pure $ nestShelfBookChapterRows flatRows

