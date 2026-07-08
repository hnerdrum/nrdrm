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

insertWidget :: Pool Connection -> Text -> IO WidgetRow
insertWidget pool name = do
  result <-
    Insert.insert @WidgetTable
      pool
      WidgetCreate
        { id = Nothing,
          createdAt = Nothing,
          updatedAt = Nothing,
          name,
          description = Omit
        }
  case result of
    Left err -> fail $ "Failed to insert widget: " ++ show err
    Right widget -> return widget