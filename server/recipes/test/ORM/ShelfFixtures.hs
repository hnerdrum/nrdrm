module ORM.ShelfFixtures
  ( insertShelf,
    insertBook,
    insertChapter,
  )
where

import Data.Pool (Pool)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple
import qualified ORM.Insert as Insert
import Schema.Book (BookCreate (..), BookRow (..), BookTable)
import Schema.Chapter (ChapterCreate (..), ChapterRow (..), ChapterTable)
import Schema.Shelf (ShelfCreate (..), ShelfRow (..), ShelfTable)
import Support.Assert (assertRight)

insertShelf :: Pool Connection -> Text -> IO ShelfRow
insertShelf pool name =
  Insert.insert @ShelfTable @ShelfRow
    pool
    ShelfCreate {id = Nothing, name}
    >>= assertRight

insertBook :: Pool Connection -> UUID -> Text -> IO BookRow
insertBook pool shelfId title =
  Insert.insert @BookTable @BookRow
    pool
    BookCreate {id = Nothing, shelfId, title}
    >>= assertRight

insertChapter :: Pool Connection -> UUID -> Text -> IO ChapterRow
insertChapter pool bookRef heading =
  Insert.insert @ChapterTable @ChapterRow
    pool
    ChapterCreate {id = Nothing, bookRef, heading}
    >>= assertRight
