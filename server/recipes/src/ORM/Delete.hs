{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module ORM.Delete
  ( DeleteBuilder,
    deleteWhere,
    deleteMany,
    deleteReturning,
    whereDelete,
    emptyDelete,
  )
where

import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple (Connection)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.ToField (Action)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Core (Entity (..))
import ORM.Db (Db (..))
import ORM.Query (QueryBuilder, buildWhereClause, queryWhereClauses, selectAll)

data DeleteBuilder table = DeleteBuilder
  { dbTable :: Text,
    dbWhere :: [Text],
    dbWhereParams :: [Action]
  }

emptyDelete :: forall table. (Entity table) => DeleteBuilder table
emptyDelete =
  DeleteBuilder
    { dbTable = tableName @table,
      dbWhere = [],
      dbWhereParams = []
    }

whereDelete :: Text -> [Action] -> DeleteBuilder table -> DeleteBuilder table
whereDelete condition params builder =
  builder
    { dbWhere = dbWhere builder ++ [condition],
      dbWhereParams = dbWhereParams builder ++ params
    }

deleteWhere ::
  forall table.
  (Entity table) =>
  DeleteBuilder table ->
  Db Int
deleteWhere builder = Db (`runDeleteWhere` builder)

deleteMany ::
  forall table.
  (Entity table) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db Int
deleteMany modifier =
  let qb = modifier (selectAll @table)
   in deleteWhere (fromQueryWhere @table qb)

fromQueryWhere :: forall table. (Entity table) => QueryBuilder table -> DeleteBuilder table
fromQueryWhere qb =
  foldl
    (\builder (condition, params) -> whereDelete condition params builder)
    (emptyDelete @table)
    (queryWhereClauses qb)

deleteReturning ::
  forall table result.
  (Entity table, FromRow result) =>
  DeleteBuilder table ->
  Db [result]
deleteReturning builder = Db (`runDeleteReturning` builder)

runDeleteWhere ::
  Connection ->
  DeleteBuilder table ->
  IO Int
runDeleteWhere conn builder = do
  let queryText =
        "DELETE FROM "
          <> dbTable builder
          <> buildWhereClause (dbWhere builder)
      query = Query (TE.encodeUtf8 queryText)
  fromIntegral <$> PGSimple.execute conn query (dbWhereParams builder)

runDeleteReturning ::
  forall table result.
  (FromRow result) =>
  Connection ->
  DeleteBuilder table ->
  IO [result]
runDeleteReturning conn builder = do
  let queryText =
        "DELETE FROM "
          <> dbTable builder
          <> buildWhereClause (dbWhere builder)
          <> " RETURNING *"
      query = Query (TE.encodeUtf8 queryText)
  PGSimple.queryWith fromRow conn query (dbWhereParams builder)
