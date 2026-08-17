{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Operations
  ( findMany,
    findUnique,
    findUniqueOrFail,
    findFirst,
    findFirstOrFail,
    count,
    delete,
    ORMError (..),
  )
where

import qualified Data.Text as Text
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField)
import ORM.Core (Entity (..), PrimaryKeyType)
import ORM.Db (Db (..))
import qualified ORM.Delete as Delete
import ORM.Errors (ORMError (..), requireFound)
import ORM.Query
  ( QueryBuilder,
    matching,
    runCountQuery,
    runQuery,
    runQueryOne,
    selectAll,
  )
import ORM.Where (compileWhere, eq)

findMany ::
  forall table result.
  (Entity table, FromRow result) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db [result]
findMany modifier = runQuery (modifier (selectAll @table))

findUnique ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table)) =>
  PrimaryKeyType table ->
  Db (Maybe result)
findUnique pkValue =
  runQueryOne $
    matching (eq (primaryKey @table) pkValue) (selectAll @table)

findUniqueOrFail ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table), Show (PrimaryKeyType table)) =>
  PrimaryKeyType table ->
  Db (Either ORMError result)
findUniqueOrFail pkValue = do
  result <- findUnique @table @result pkValue
  pure $
    requireFound result $
      RecordNotFound ("Record not found with primary key: " <> Text.pack (show pkValue))

findFirst ::
  forall table result.
  (Entity table, FromRow result) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db (Maybe result)
findFirst modifier = runQueryOne (modifier (selectAll @table))

findFirstOrFail ::
  forall table result.
  (Entity table, FromRow result) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db (Either ORMError result)
findFirstOrFail modifier = do
  result <- findFirst @table modifier
  pure $
    requireFound result $
      RecordNotFound "No record found matching criteria"

count ::
  forall table.
  (Entity table) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db Int
count modifier = runCountQuery (modifier (selectAll @table))

delete ::
  forall table.
  (Entity table, ToField (PrimaryKeyType table)) =>
  PrimaryKeyType table ->
  Db Int
delete pkValue =
  let (sql, params) = compileWhere (eq (primaryKey @table) pkValue)
      builder = Delete.whereDelete sql params (Delete.emptyDelete @table)
   in Delete.deleteWhere builder
