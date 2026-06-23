{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Query
  ( Query,
    QueryBuilder,
    select,
    selectAll,
    where_,
    whereEq,
    orderBy,
    limit,
    OrderDirection (..),
    runQuery,
    runQueryOne,
  )
where

import Data.Pool (Pool, withResource)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple (Connection)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.ToField (Action, ToField, toField)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Core (Entity (..), Field (..))

data QueryBuilder table = QueryBuilder
  { qbTable :: Text,
    qbWhere :: [Text],
    qbParams :: [Action],
    qbOrderBy :: Maybe (Text, OrderDirection),
    qbLimit :: Maybe Int
  }

data OrderDirection = Asc | Desc

selectAll :: forall table. (Entity table) => QueryBuilder table
selectAll =
  QueryBuilder
    { qbTable = tableName @table,
      qbWhere = [],
      qbParams = [],
      qbOrderBy = Nothing,
      qbLimit = Nothing
    }

select :: forall table. (Entity table) => QueryBuilder table
select = selectAll @table

where_ :: Text -> [Action] -> QueryBuilder table -> QueryBuilder table
where_ condition params qb =
  qb
    { qbWhere = qbWhere qb ++ [condition],
      qbParams = qbParams qb ++ params
    }

whereEq :: forall table a. (ToField a) => Field table a -> a -> QueryBuilder table -> QueryBuilder table
whereEq field value =
  where_
    (fieldColumn field <> " = ?")
    [toField value]

orderBy :: Field table a -> OrderDirection -> QueryBuilder table -> QueryBuilder table
orderBy field dir qb =
  qb {qbOrderBy = Just (fieldColumn field, dir)}

limit :: Int -> QueryBuilder table -> QueryBuilder table
limit n qb = qb {qbLimit = Just n}

buildQuery :: QueryBuilder table -> (Query, [Action])
buildQuery qb =
  let baseQuery = "SELECT * FROM " <> qbTable qb
      whereClause =
        buildWhereClause (qbWhere qb)
      orderClause = buildOrderClause (qbOrderBy qb)
      limitClause = buildLimitClause (qbLimit qb)
      finalQuery = baseQuery <> whereClause <> orderClause <> limitClause
   in (Query (TE.encodeUtf8 finalQuery), qbParams qb)

buildWhereClause :: [Text] -> Text
buildWhereClause [] = ""
buildWhereClause conditions = " WHERE " <> T.intercalate " AND " conditions

buildOrderClause :: Maybe (Text, OrderDirection) -> Text
buildOrderClause Nothing = ""
buildOrderClause (Just (col, dir)) =
  " ORDER BY " <> col <> case dir of
    Asc -> " ASC"
    Desc -> " DESC"

buildLimitClause :: Maybe Int -> Text
buildLimitClause Nothing = ""
buildLimitClause (Just n) = " LIMIT " <> T.pack (show n)

runQuery :: (FromRow result) => Pool Connection -> QueryBuilder table -> IO [result]
runQuery pool qb =
  withResource pool $ \conn -> do
    let (query, params) = buildQuery qb
    PGSimple.queryWith fromRow conn query params

runQueryOne :: (FromRow result) => Pool Connection -> QueryBuilder table -> IO (Maybe result)
runQueryOne pool qb = do
  results <- runQuery pool (limit 1 qb)
  return $ case results of
    [] -> Nothing
    (x : _) -> Just x
