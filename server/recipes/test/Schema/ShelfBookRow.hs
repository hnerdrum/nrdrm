module Schema.ShelfBookRow
  ( ShelfBookJoinRow (..),
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)

data ShelfBookJoinRow = ShelfBookJoinRow
  { shelfId :: UUID,
    shelfName :: Text,
    bookId :: Maybe UUID,
    bookTitle :: Maybe Text
  }
  deriving (Show, Eq)

instance FromRow ShelfBookJoinRow where
  fromRow = ShelfBookJoinRow <$> field <*> field <*> field <*> field
