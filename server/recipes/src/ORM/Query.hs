{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Query
  ( Query,
    QueryBuilder,
    WherePred (..),
    queryWherePreds,
    queryWhereClauses,
    queryWhereConditions,
    queryWhereParams,
    queryLimit,
    queryOffset,
    queryOrderBy,
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
import ORM.Sql (quoteIdent)

data QueryBuilder table = QueryBuilder
  { qbTable :: Text,
    qbWhere :: [WherePred],
    qbOrderBy :: Maybe (Text, OrderDirection),
    qbLimit :: Maybe Int,
    qbOffset :: Maybe Int
  }

-- | A WHERE predicate. Column equalities can be alias-qualified for joins;
-- raw SQL cannot, and is rejected on include queries.
data WherePred
  = WhereColumnEq Text Action
  | WhereRaw Text [Action]

data OrderDirection = Asc | Desc

selectAll :: forall table. (Entity table) => QueryBuilder table
selectAll =
  QueryBuilder
    { qbTable = tableName @table,
      qbWhere = [],
      qbOrderBy = Nothing,
      qbLimit = Nothing,
      qbOffset = Nothing
    }

select :: forall table. (Entity table) => QueryBuilder table
select = selectAll @table

where_ :: Text -> [Action] -> QueryBuilder table -> QueryBuilder table
where_ condition params qb =
  qb {qbWhere = qbWhere qb ++ [WhereRaw condition params]}

whereEq :: forall table a. (ToField a) => Field table a -> a -> QueryBuilder table -> QueryBuilder table
whereEq field value qb =
  qb {qbWhere = qbWhere qb ++ [WhereColumnEq (fieldColumn field) (toField value)]}

orderBy :: Field table a -> OrderDirection -> QueryBuilder table -> QueryBuilder table
orderBy field dir qb =
  qb {qbOrderBy = Just (fieldColumn field, dir)}

limit :: Int -> QueryBuilder table -> QueryBuilder table
limit n qb = qb {qbLimit = Just n}

offset :: Int -> QueryBuilder table -> QueryBuilder table
offset n qb = qb {qbOffset = Just n}

queryWherePreds :: QueryBuilder table -> [WherePred]
queryWherePreds = qbWhere

queryWhereClauses :: QueryBuilder table -> [(Text, [Action])]
queryWhereClauses qb =
  [(wherePredSql wp, wherePredParams wp) | wp <- qbWhere qb]

queryWhereConditions :: QueryBuilder table -> [Text]
queryWhereConditions = map fst . queryWhereClauses

queryWhereParams :: QueryBuilder table -> [Action]
queryWhereParams = concatMap snd . queryWhereClauses

wherePredSql :: WherePred -> Text
wherePredSql (WhereColumnEq col _) = quoteIdent col <> " = ?"
wherePredSql (WhereRaw sql _) = sql

wherePredParams :: WherePred -> [Action]
wherePredParams (WhereColumnEq _ value) = [value]
wherePredParams (WhereRaw _ params) = params

queryLimit :: QueryBuilder table -> Maybe Int
queryLimit = qbLimit

queryOffset :: QueryBuilder table -> Maybe Int
queryOffset = qbOffset

queryOrderBy :: QueryBuilder table -> Maybe (Text, OrderDirection)
queryOrderBy = qbOrderBy

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
  let baseQuery = "SELECT * FROM " <> quoteIdent (qbTable qb)
      clauses = queryWhereClauses qb
      whereClause = buildWhereClause (map fst clauses)
      orderClause = buildOrderClause (qbOrderBy qb)
      limitClause = buildLimitClause (qbLimit qb)
      offsetClause = buildOffsetClause (qbOffset qb)
      finalQuery = baseQuery <> whereClause <> orderClause <> limitClause <> offsetClause
   in (Query (TE.encodeUtf8 finalQuery), concatMap snd clauses)

buildCountQuery :: QueryBuilder table -> (Query, [Action])
buildCountQuery qb =
  let clauses = queryWhereClauses qb
      finalQuery = "SELECT COUNT(*) FROM " <> quoteIdent (qbTable qb) <> buildWhereClause (map fst clauses)
   in (Query (TE.encodeUtf8 finalQuery), concatMap snd clauses)

buildWhereClause :: [Text] -> Text
buildWhereClause [] = ""
buildWhereClause conditions = " WHERE " <> T.intercalate " AND " conditions

buildOrderClause :: Maybe (Text, OrderDirection) -> Text
buildOrderClause Nothing = ""
buildOrderClause (Just (col, dir)) =
  " ORDER BY " <> quoteIdent col <> case dir of
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
