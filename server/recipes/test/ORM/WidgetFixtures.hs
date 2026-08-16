module ORM.WidgetFixtures
  ( insertWidget,
  )
where

import Data.Pool (Pool)
import Data.Text (Text)
import Database.PostgreSQL.Simple (Connection)
import ORM (NullableValue (Omit), runDb)
import qualified ORM.Insert as Insert
import Schema.Widget
import Support.Assert (assertRight)

insertWidget :: Pool Connection -> Text -> IO WidgetRow
insertWidget pool name =
  runDb
    pool
    ( Insert.insert @WidgetTable @WidgetRow
        WidgetCreate
          { id = Nothing,
            createdAt = Nothing,
            updatedAt = Nothing,
            name,
            description = Omit
          }
    )
    >>= assertRight
