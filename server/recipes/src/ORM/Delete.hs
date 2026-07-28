{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module ORM.Delete
  ( DeleteBuilder,
    delete,
    deleteConn,
    deleteReturning,
    deleteReturningConn,
    whereDelete,
    emptyDelete,
  )
where

import Data.Pool (Pool, withResource)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple (Connection)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.ToField (Action)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Core (Entity (..))

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

delete ::
  forall table.
  (Entity table) =>
  Pool Connection ->
  DeleteBuilder table ->
  IO Int
delete pool builder =
  withResource pool $ \conn -> deleteConn conn builder

deleteConn ::
  forall table.
  (Entity table) =>
  Connection ->
  DeleteBuilder table ->
  IO Int
deleteConn conn builder = do
  let whereClause =
        if null (dbWhere builder)
          then ""
          else " WHERE " <> Text.intercalate " AND " (dbWhere builder)
      queryText =
        "DELETE FROM "
          <> dbTable builder
          <> whereClause
      query = Query (TE.encodeUtf8 queryText)
  fromIntegral <$> PGSimple.execute conn query (dbWhereParams builder)

deleteReturning ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  DeleteBuilder table ->
  IO [result]
deleteReturning pool builder =
  withResource pool $ \conn -> deleteReturningConn conn builder

deleteReturningConn ::
  forall table result.
  (Entity table, FromRow result) =>
  Connection ->
  DeleteBuilder table ->
  IO [result]
deleteReturningConn conn builder = do
  let whereClause =
        if null (dbWhere builder)
          then ""
          else " WHERE " <> Text.intercalate " AND " (dbWhere builder)
      queryText =
        "DELETE FROM "
          <> dbTable builder
          <> whereClause
          <> " RETURNING *"
      query = Query (TE.encodeUtf8 queryText)
  PGSimple.queryWith fromRow conn query (dbWhereParams builder)
