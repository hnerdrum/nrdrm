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
    create,
    updateByPk,
    deleteByPk,
    ORMError (..),
  )
where

import Data.Pool (Pool)
import qualified Data.Text as Text
import Data.UUID (UUID)
import qualified Data.UUID.V4 as V4
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField, toField)
import ORM.Core (Entity (..), Field (..), PrimaryKeyType)
import qualified ORM.Delete as Delete
import ORM.Errors (ORMError (..))
import qualified ORM.Insert as Insert
import ORM.Query (QueryBuilder, runQuery, runQueryOne, selectAll, whereEq)
import qualified ORM.Update as Update

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
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  (QueryBuilder table -> QueryBuilder table) ->
  IO Int
count pool modifier = do
  results :: [result] <- runQuery pool (modifier (selectAll @table))
  return $ length results

create ::
  forall table result.
  (Entity table, FromRow result, PrimaryKeyType table ~ UUID, Show (PrimaryKeyType table)) =>
  Pool Connection ->
  Insert.InsertBuilder table ->
  IO (Either ORMError result)
create pool builder = do
  pkValue <- V4.nextRandom
  Insert.insert pool pkValue builder

updateByPk ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  Update.UpdateBuilder table ->
  IO (Either ORMError result)
updateByPk pool pkValue builder = do
  let pkField = primaryKey @table
      builderWithWhere = Update.whereUpdate (fieldColumn pkField <> " = ?") [toField pkValue] builder
  Update.update pool builderWithWhere

deleteByPk ::
  forall table.
  (Entity table, ToField (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  IO Int
deleteByPk pool pkValue =
  let pkField = primaryKey @table
      builder = Delete.whereDelete (fieldColumn pkField <> " = ?") [toField pkValue] (Delete.emptyDelete @table)
   in Delete.delete pool builder
