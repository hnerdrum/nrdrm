{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Query
  ( Query,
    QueryBuilder,
    queryWhereConditions,
    queryWhereParams,
    queryLimit,
    select,
    selectAll,
    where_,
    whereEq,
    orderBy,
    limit,
    offset,
    applyQueryModifiers,
    OrderDirection (..),
    buildWhereClause,
    runQuery,
    runQueryOne,
    runCountQuery,
  )
where

import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple (Only (..))
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.ToField (Action, ToField, toField)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Core (Entity (..), Field (..))
import ORM.Db (Db (..))

data QueryBuilder table = QueryBuilder
  { qbTable :: Text,
    qbWhere :: [Text],
    qbParams :: [Action],
    qbOrderBy :: Maybe (Text, OrderDirection),
    qbLimit :: Maybe Int,
    qbOffset :: Maybe Int
  }

data OrderDirection = Asc | Desc

selectAll :: forall table. (Entity table) => QueryBuilder table
selectAll =
  QueryBuilder
    { qbTable = tableName @table,
      qbWhere = [],
      qbParams = [],
      qbOrderBy = Nothing,
      qbLimit = Nothing,
      qbOffset = Nothing
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

offset :: Int -> QueryBuilder table -> QueryBuilder table
offset n qb = qb {qbOffset = Just n}

queryWhereConditions :: QueryBuilder table -> [Text]
queryWhereConditions = qbWhere

queryWhereParams :: QueryBuilder table -> [Action]
queryWhereParams = qbParams

queryLimit :: QueryBuilder table -> Maybe Int
queryLimit = qbLimit

applyQueryModifiers ::
  Maybe (QueryBuilder table -> QueryBuilder table) ->
  Maybe (QueryBuilder table -> QueryBuilder table) ->
  Maybe Int ->
  Maybe Int ->
  QueryBuilder table ->
  QueryBuilder table
applyQueryModifiers mWhere mOrder mLimit mOffset =
  fromMaybe id mWhere
    . fromMaybe id mOrder
    . maybe id limit mLimit
    . maybe id offset mOffset

buildQuery :: QueryBuilder table -> (Query, [Action])
buildQuery qb =
  let baseQuery = "SELECT * FROM " <> qbTable qb
      whereClause = buildWhereClause (qbWhere qb)
      orderClause = buildOrderClause (qbOrderBy qb)
      limitClause = buildLimitClause (qbLimit qb)
      offsetClause = buildOffsetClause (qbOffset qb)
      finalQuery = baseQuery <> whereClause <> orderClause <> limitClause <> offsetClause
   in (Query (TE.encodeUtf8 finalQuery), qbParams qb)

buildCountQuery :: QueryBuilder table -> (Query, [Action])
buildCountQuery qb =
  let finalQuery = "SELECT COUNT(*) FROM " <> qbTable qb <> buildWhereClause (qbWhere qb)
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

buildOffsetClause :: Maybe Int -> Text
buildOffsetClause Nothing = ""
buildOffsetClause (Just n) = " OFFSET " <> T.pack (show n)

runQuery :: (FromRow result) => QueryBuilder table -> Db [result]
runQuery qb =
  Db $ \conn -> do
    let (query, params) = buildQuery qb
    PGSimple.queryWith fromRow conn query params

runQueryOne :: (FromRow result) => QueryBuilder table -> Db (Maybe result)
runQueryOne qb = do
  results <- runQuery (limit 1 qb)
  pure $ case results of
    [] -> Nothing
    (x : _) -> Just x

runCountQuery :: QueryBuilder table -> Db Int
runCountQuery qb =
  Db $ \conn -> do
    let (query, params) = buildCountQuery qb
    [Only count] <- PGSimple.query conn query params
    pure (fromIntegral (count :: Int64))
