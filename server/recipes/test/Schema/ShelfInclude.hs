{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Schema.ShelfInclude
  ( ShelfInclude (..),
    ShelfWithBooks (..),
  )
where

import Data.Maybe (mapMaybe)
import ORM.Group (groupByKey)
import ORM.Include (BuildJoinChain (..), IncludesJoin (..), NestInclude (..))
import qualified ORM.JoinChain as JoinChain
import Schema.Shelf (BookRow (..), ShelfRow (..), ShelfTable, shelfBooks)
import qualified Schema.Shelf as Shelf
import Schema.ShelfBookRow (ShelfBookJoinRow (..))

data ShelfInclude = ShelfInclude
  { books :: Bool
  }
  deriving (Show, Eq)

data ShelfWithBooks = ShelfWithBooks
  { shelf :: ShelfRow,
    books :: [BookRow]
  }
  deriving (Show, Eq)

instance IncludesJoin ShelfInclude where
  includesJoin ShelfInclude {books} = books

instance BuildJoinChain ShelfTable ShelfInclude where
  type JoinFlatRow ShelfInclude = ShelfBookJoinRow
  buildJoinChain _ =
    JoinChain.selectColumns
      [ JoinChain.col "s" Shelf.shelfId,
        JoinChain.col "s" Shelf.shelfName,
        JoinChain.col "b" Shelf.bookId,
        JoinChain.col "b" Shelf.bookTitle
      ]
      (JoinChain.buildJoinChainFromHasMany shelfBooks "s" "b")

instance NestInclude ShelfInclude ShelfWithBooks where
  type RootRow ShelfInclude = ShelfRow
  nestRows _ = map shelfWithBooksFromGroup . groupByKey (.shelfId)
  wrapRoot _ shelf = ShelfWithBooks {shelf, books = []}

shelfWithBooksFromGroup :: [ShelfBookJoinRow] -> ShelfWithBooks
shelfWithBooksFromGroup rows@(firstRow : _) =
  ShelfWithBooks
    { shelf = toShelfRow firstRow,
      books = mapMaybe toBookRow rows
    }
shelfWithBooksFromGroup [] =
  error "shelfWithBooksFromGroup: empty group"

toShelfRow :: ShelfBookJoinRow -> ShelfRow
toShelfRow row = ShelfRow {id = row.shelfId, name = row.shelfName}

toBookRow :: ShelfBookJoinRow -> Maybe BookRow
toBookRow row
  | Just bid <- row.bookId,
    Just title <- row.bookTitle =
      Just BookRow {id = bid, shelfRef = row.shelfId, title}
  | otherwise = Nothing
