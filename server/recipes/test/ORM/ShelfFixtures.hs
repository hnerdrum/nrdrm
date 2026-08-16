module ORM.ShelfFixtures
  ( insertShelf,
    insertBook,
    insertChapter,
    insertSection,
  )
where

import Data.Pool (Pool)
import Data.Text (Text)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection)
import ORM (runDb)
import qualified ORM.Insert as Insert
import Schema.Book (BookCreate (..), BookRow (..), BookTable)
import Schema.Chapter (ChapterCreate (..), ChapterRow (..), ChapterTable)
import Schema.Section (SectionCreate (..), SectionRow (..), SectionTable)
import Schema.Shelf (ShelfCreate (..), ShelfRow (..), ShelfTable)
import Support.Assert (assertRight)

insertShelf :: Pool Connection -> Text -> IO ShelfRow
insertShelf pool name =
  runDb pool (Insert.insert @ShelfTable @ShelfRow (ShelfCreate {id = Nothing, name}))
    >>= assertRight

insertBook :: Pool Connection -> UUID -> Text -> IO BookRow
insertBook pool shelfId title =
  runDb pool (Insert.insert @BookTable @BookRow (BookCreate {id = Nothing, shelfId, title}))
    >>= assertRight

insertChapter :: Pool Connection -> UUID -> Text -> IO ChapterRow
insertChapter pool bookRef heading =
  runDb pool (Insert.insert @ChapterTable @ChapterRow (ChapterCreate {id = Nothing, bookRef, heading}))
    >>= assertRight

insertSection :: Pool Connection -> UUID -> Text -> IO SectionRow
insertSection pool chapterRef label =
  runDb pool (Insert.insert @SectionTable @SectionRow (SectionCreate {id = Nothing, chapterRef, label}))
    >>= assertRight
