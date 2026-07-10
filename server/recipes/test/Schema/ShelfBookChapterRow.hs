module Schema.ShelfBookChapterRow
  ( ShelfBookChapterJoinRow (..),
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)

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
  fromRow =
    ShelfBookChapterJoinRow
      <$> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
