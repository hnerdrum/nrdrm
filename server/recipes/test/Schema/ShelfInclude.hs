{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Schema.ShelfInclude
  ( ShelfInclude (..),
    BookInclude (..),
    ShelfWithBooks (..),
    BookWithChapters (..),
  )
where

import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Text (Text)
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
import Schema.Shelf
  ( BookRow (..),
    ChapterRow (..),
    ShelfRow (..),
    ShelfTable,
    bookChapters,
    shelfBooks,
  )
import qualified Schema.Shelf as Shelf
import Schema.ShelfBookChapterRow (ShelfBookChapterJoinRow (..))
import Schema.ShelfBookRow (ShelfBookJoinRow (..))

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

shelfBookColumns :: [Text]
shelfBookColumns =
  [ JoinChain.col "s" Shelf.shelfId,
    JoinChain.col "s" Shelf.shelfName,
    JoinChain.col "b" Shelf.bookId,
    JoinChain.col "b" Shelf.bookTitle
  ]

shelfBookChapterColumns :: [Text]
shelfBookChapterColumns =
  shelfBookColumns
    ++ [ JoinChain.col "c" Shelf.chapterId,
         JoinChain.col "c" Shelf.chapterHeading
       ]

buildShelfBookJoin :: JoinChain.JoinChain ShelfTable
buildShelfBookJoin =
  JoinChain.selectColumns shelfBookColumns $
    JoinChain.buildJoinChainFromHasMany shelfBooks "s" "b"

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

nestShelfBookChapterRows :: [ShelfBookChapterJoinRow] -> [ShelfWithBooks]
nestShelfBookChapterRows =
  map shelfWithChaptersFromShelfGroup . groupByKey (.shelfId)

shelfWithBooksFromGroup :: [ShelfBookJoinRow] -> ShelfWithBooks
shelfWithBooksFromGroup rows@(firstRow : _) =
  ShelfWithBooks
    { shelf = toShelfRow firstRow,
      books = map bookWithNoChapters $ mapMaybe toBookRow rows
    }
shelfWithBooksFromGroup [] =
  error "shelfWithBooksFromGroup: empty group"

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

bookWithNoChapters :: BookRow -> BookWithChapters
bookWithNoChapters book = BookWithChapters {book, chapters = []}

toShelfRow :: ShelfBookJoinRow -> ShelfRow
toShelfRow row = ShelfRow {id = row.shelfId, name = row.shelfName}

toShelfRowFromChapter :: ShelfBookChapterJoinRow -> ShelfRow
toShelfRowFromChapter row = ShelfRow {id = row.shelfId, name = row.shelfName}

toBookRow :: ShelfBookJoinRow -> Maybe BookRow
toBookRow row
  | Just bid <- row.bookId,
    Just title <- row.bookTitle =
      Just BookRow {id = bid, shelfRef = row.shelfId, title}
  | otherwise = Nothing

toBookRowFromChapter :: ShelfBookChapterJoinRow -> BookRow
toBookRowFromChapter row =
  BookRow
    { id = fromMaybe (error "toBookRowFromChapter: missing book id") row.bookId,
      shelfRef = row.shelfId,
      title = fromMaybe (error "toBookRowFromChapter: missing book title") row.bookTitle
    }

toChapterRow :: ShelfBookChapterJoinRow -> Maybe ChapterRow
toChapterRow row
  | Just cid <- row.chapterId,
    Just heading <- row.chapterHeading,
    Just bid <- row.bookId =
      Just ChapterRow {id = cid, bookRef = bid, heading}
  | otherwise = Nothing

instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable ShelfInclude ShelfWithBooks where
  executeInclude conn include modifier =
    case include.books of
      Nothing -> do
        shelves <- findManyConn @ShelfTable @ShelfRow conn modifier
        pure $ map (wrapRoot include) shelves
      Just BookInclude {chapters = False} -> do
        let chain = applyRootFilter buildShelfBookJoin modifier
        flatRows <- JoinChain.runJoinChainConn @ShelfBookJoinRow conn chain
        pure $ nestShelfRows flatRows
      Just BookInclude {chapters = True} -> do
        let chain = applyRootFilter buildShelfBookChapterJoin modifier
        flatRows <- JoinChain.runJoinChainConn @ShelfBookChapterJoinRow conn chain
        pure $ nestShelfBookChapterRows flatRows
