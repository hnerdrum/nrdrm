module ORM.WidgetFixtures
  ( insertWidget,
  )
where

import Data.Pool (Pool)
import Data.Text (Text)
import Database.PostgreSQL.Simple
import ORM (NullableValue (Omit))
import qualified ORM.Insert as Insert
import Schema.Widget
import Support.Assert (assertRight)

insertWidget :: Pool Connection -> Text -> IO WidgetRow
insertWidget pool name =
  Insert.insert @WidgetTable @WidgetRow
    pool
    WidgetCreate
      { id = Nothing,
        createdAt = Nothing,
        updatedAt = Nothing,
        name,
        description = Omit
      }
    >>= assertRight
