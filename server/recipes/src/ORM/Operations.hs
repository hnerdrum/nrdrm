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
    delete,
    ORMError (..),
  )
where

import Data.Pool (Pool)
import qualified Data.Text as Text
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField, toField)
import ORM.Core (Entity (..), Field (..), PrimaryKeyType)
import qualified ORM.Delete as Delete
import ORM.Errors (ORMError (..))
import ORM.Query (QueryBuilder, runCountQuery, runQuery, runQueryOne, selectAll, whereEq)

findAll ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  IO [result]
findAll pool =
  runQuery pool (selectAll @table)

findMany ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  (QueryBuilder table -> QueryBuilder table) ->
  IO [result]
findMany pool modifier =
  runQuery pool (modifier (selectAll @table))

findUnique ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  IO (Maybe result)
findUnique pool pkValue =
  runQueryOne pool $
    whereEq (primaryKey @table) pkValue (selectAll @table)

findUniqueOrError ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table), Show (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  IO (Either ORMError result)
findUniqueOrError pool pkValue = do
  result <- findUnique @table pool pkValue
  case result of
    Nothing -> return $ Left $ RecordNotFound ("Record not found with primary key: " <> (Text.pack . show) pkValue)
    Just record -> return $ Right record

findFirst ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  (QueryBuilder table -> QueryBuilder table) ->
  IO (Maybe result)
findFirst pool modifier =
  runQueryOne pool (modifier (selectAll @table))

findFirstOrError ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  (QueryBuilder table -> QueryBuilder table) ->
  IO (Either ORMError result)
findFirstOrError pool modifier = do
  result <- findFirst @table pool modifier
  case result of
    Nothing -> return $ Left $ RecordNotFound "No record found matching criteria"
    Just record -> return $ Right record

count ::
  forall table.
  Entity table =>
  Pool Connection ->
  (QueryBuilder table -> QueryBuilder table) ->
  IO Int
count pool modifier =
  runCountQuery pool (modifier (selectAll @table))

delete ::
  forall table.
  (Entity table, ToField (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  IO Int
delete pool pkValue =
  let pkField = primaryKey @table
      builder = Delete.whereDelete (fieldColumn pkField <> " = ?") [toField pkValue] (Delete.emptyDelete @table)
   in Delete.delete pool builder
