module ORM.Sql
  ( Param (..),
    param,
    queryRaw,
    executeRaw,
    catchDb,
    catchSql,
    fromSqlError,
  )
where

import Control.Exception (catch)
import qualified Data.Text.Encoding as TE
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.Internal (SqlError (..))
import Database.PostgreSQL.Simple.ToField (Action, ToField, toField)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Db (Db (..))
import ORM.Errors (ORMError (..))

newtype Param = Param {unParam :: Action}

param :: (ToField a) => a -> Param
param = Param . toField

queryRaw :: (FromRow r) => Query -> [Param] -> Db [r]
queryRaw query params =
  Db $ \conn ->
    PGSimple.queryWith fromRow conn query (map unParam params)

executeRaw :: Query -> [Param] -> Db Int
executeRaw query params =
  Db $ \conn ->
    fromIntegral <$> PGSimple.execute conn query (map unParam params)

catchDb :: Db a -> Db (Either ORMError a)
catchDb (Db action) = Db $ \conn -> catchSql (action conn)

catchSql :: IO a -> IO (Either ORMError a)
catchSql action =
  (Right <$> action) `catch` (pure . Left . fromSqlError)

fromSqlError :: SqlError -> ORMError
fromSqlError SqlError {sqlState = state, sqlErrorMsg = msg}
  | state == "23505" = UniqueViolation (decode msg)
  | otherwise = DatabaseError (decode msg)
  where
    decode = TE.decodeUtf8
