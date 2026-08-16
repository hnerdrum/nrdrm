{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Operations
  ( findAll,
    findMany,
    findUnique,
    findUniqueOrError,
    findFirst,
    findFirstOrError,
    count,
    deleteById,
    ORMError (..),
  )
where

import qualified Data.Text as Text
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField, toField)
import ORM.Core (Entity (..), Field (..), PrimaryKeyType)
import ORM.Db (Db (..))
import qualified ORM.Delete as Delete
import ORM.Errors (ORMError (..))
import ORM.Query
  ( QueryBuilder,
    runCountQuery,
    runQuery,
    runQueryOne,
    selectAll,
    whereEq,
  )

findAll ::
  forall table result.
  (Entity table, FromRow result) =>
  Db [result]
findAll = runQuery (selectAll @table)

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
    whereEq (primaryKey @table) pkValue (selectAll @table)

findUniqueOrError ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table), Show (PrimaryKeyType table)) =>
  PrimaryKeyType table ->
  Db (Either ORMError result)
findUniqueOrError pkValue = do
  result <- findUnique @table @result pkValue
  case result of
    Nothing ->
      pure $
        Left $
          RecordNotFound ("Record not found with primary key: " <> (Text.pack . show) pkValue)
    Just record -> pure $ Right record

findFirst ::
  forall table result.
  (Entity table, FromRow result) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db (Maybe result)
findFirst modifier = runQueryOne (modifier (selectAll @table))

findFirstOrError ::
  forall table result.
  (Entity table, FromRow result) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db (Either ORMError result)
findFirstOrError modifier = do
  result <- findFirst @table modifier
  case result of
    Nothing -> pure $ Left $ RecordNotFound "No record found matching criteria"
    Just record -> pure $ Right record

count ::
  forall table.
  (Entity table) =>
  (QueryBuilder table -> QueryBuilder table) ->
  Db Int
count modifier = runCountQuery (modifier (selectAll @table))

deleteById ::
  forall table.
  (Entity table, ToField (PrimaryKeyType table)) =>
  PrimaryKeyType table ->
  Db Int
deleteById pkValue =
  let pkField = primaryKey @table
      builder = Delete.whereDelete (fieldColumn pkField <> " = ?") [toField pkValue] (Delete.emptyDelete @table)
   in Delete.deleteWhere builder
