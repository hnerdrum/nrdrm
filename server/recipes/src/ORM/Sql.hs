module ORM.Sql
  ( catchSql,
    fromSqlError,
  )
where

import Control.Exception (catch)
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple.Internal (SqlError (..))
import ORM.Errors (ORMError (..))

catchSql :: IO a -> IO (Either ORMError a)
catchSql action =
  (Right <$> action) `catch` (pure . Left . fromSqlError)

fromSqlError :: SqlError -> ORMError
fromSqlError SqlError {sqlState = state, sqlErrorMsg = msg}
  | state == "23505" = UniqueViolation (decode msg)
  | otherwise = DatabaseError (decode msg)
  where
    decode = TE.decodeUtf8
