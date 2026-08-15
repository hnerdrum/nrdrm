{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module ORM.Update
  ( UpdateBuilder,
    Updatable (..),
    update,
    updateConn,
    updateBuilder,
    updateBuilderConn,
    updateReturning,
    updateReturningConn,
    setField,
    setFieldNull,
    setFieldMaybe,
    setFieldNullable,
    whereUpdate,
    emptyUpdate,
  )
where

import Data.Pool (Pool, withResource)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, getCurrentTime)
import Database.PostgreSQL.Simple (Connection)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.ToField (Action, ToField, toField)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Core (Entity (..), Field (..), NullableValue (..), PrimaryKeyType)
import ORM.Errors (ORMError (..))
import qualified ORM.Operations as Ops
import ORM.Sql (catchSql)

class (Entity table) => Updatable table where
  type UpdateInput table
  toUpdateBuilder :: UpdateInput table -> UpdateBuilder table
  updatedAtField :: Maybe (Field table UTCTime)
  default updatedAtField :: Maybe (Field table UTCTime)
  updatedAtField = Nothing

data UpdateBuilder table = UpdateBuilder
  { ubTable :: Text,
    ubSets :: [(Text, Action)],
    ubWhere :: [Text],
    ubWhereParams :: [Action]
  }

emptyUpdate :: forall table. (Entity table) => UpdateBuilder table
emptyUpdate =
  UpdateBuilder
    { ubTable = tableName @table,
      ubSets = [],
      ubWhere = [],
      ubWhereParams = []
    }

setField :: forall table a. (ToField a) => Field table a -> a -> UpdateBuilder table -> UpdateBuilder table
setField field value builder =
  builder
    { ubSets = ubSets builder ++ [(fieldColumn field, toField value)]
    }

setFieldNull ::
  forall table a.
  (ToField (Maybe a)) =>
  Field table a ->
  UpdateBuilder table ->
  UpdateBuilder table
setFieldNull field builder =
  builder
    { ubSets = ubSets builder ++ [(fieldColumn field, toField (Nothing :: Maybe a))]
    }

setFieldMaybe ::
  forall table a.
  (ToField a) =>
  Field table a ->
  Maybe a ->
  UpdateBuilder table ->
  UpdateBuilder table
setFieldMaybe _ Nothing builder = builder
setFieldMaybe field (Just value) builder = setField field value builder

setFieldNullable ::
  forall table a.
  (ToField a, ToField (Maybe a)) =>
  Field table a ->
  NullableValue a ->
  UpdateBuilder table ->
  UpdateBuilder table
setFieldNullable _ Omit builder = builder
setFieldNullable field (Value value) builder = setField field value builder
setFieldNullable field Null builder = setFieldNull field builder

whereUpdate :: Text -> [Action] -> UpdateBuilder table -> UpdateBuilder table
whereUpdate condition params builder =
  builder
    { ubWhere = ubWhere builder ++ [condition],
      ubWhereParams = ubWhereParams builder ++ params
    }

update ::
  forall table result.
  (Updatable table, FromRow result, ToField (PrimaryKeyType table), Show (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  UpdateInput table ->
  IO (Either ORMError result)
update pool pkValue input =
  withResource pool $ \conn -> updateConn @table @result conn pkValue input

updateConn ::
  forall table result.
  (Updatable table, FromRow result, ToField (PrimaryKeyType table), Show (PrimaryKeyType table)) =>
  Connection ->
  PrimaryKeyType table ->
  UpdateInput table ->
  IO (Either ORMError result)
updateConn conn pkValue input = do
  let builder = toUpdateBuilder @table input
  if null (ubSets builder)
    then Ops.findUniqueOrErrorConn @table @result conn pkValue
    else do
      now <- getCurrentTime
      let pkField = primaryKey @table
          builderWithTouch = touchUpdatedAt @table now builder
          builderWithWhere =
            whereUpdate
              (fieldColumn pkField <> " = ?")
              [toField pkValue]
              builderWithTouch
      updateBuilderConn conn builderWithWhere

updateBuilder ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  UpdateBuilder table ->
  IO (Either ORMError result)
updateBuilder pool builder =
  withResource pool $ \conn -> updateBuilderConn conn builder

updateBuilderConn ::
  forall table result.
  (Entity table, FromRow result) =>
  Connection ->
  UpdateBuilder table ->
  IO (Either ORMError result)
updateBuilderConn conn builder = do
  result <- catchSql (updateReturningConn conn builder)
  case result of
    Left err -> pure $ Left err
    Right [] -> pure $ Left $ RecordNotFound "No record found to update"
    Right [row] -> pure $ Right row
    Right _ -> pure $ Left $ MultipleRecordsFound "Update affected multiple rows"

updateReturning ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  UpdateBuilder table ->
  IO [result]
updateReturning pool builder =
  withResource pool $ \conn -> updateReturningConn conn builder

updateReturningConn ::
  forall table result.
  (Entity table, FromRow result) =>
  Connection ->
  UpdateBuilder table ->
  IO [result]
updateReturningConn conn builder = do
  let setClause = buildSetClause (ubSets builder)
      setParams = map snd (ubSets builder)
      whereClause = buildWhereClause (ubWhere builder)
      allParams = setParams ++ ubWhereParams builder
      queryText =
        "UPDATE "
          <> ubTable builder
          <> setClause
          <> whereClause
          <> " RETURNING *"
      query = Query (TE.encodeUtf8 queryText)
  PGSimple.queryWith fromRow conn query allParams

buildSetClause :: [(Text, Action)] -> Text
buildSetClause sets = " SET " <> Text.intercalate ", " (map (\(col, _) -> col <> " = ?") sets)

buildWhereClause :: [Text] -> Text
buildWhereClause [] = ""
buildWhereClause conditions = " WHERE " <> Text.intercalate " AND " conditions

touchUpdatedAt ::
  forall table.
  (Updatable table) =>
  UTCTime ->
  UpdateBuilder table ->
  UpdateBuilder table
touchUpdatedAt now builder =
  case updatedAtField @table of
    Nothing -> builder
    Just field ->
      if fieldColumn field `elem` map fst (ubSets builder)
        then builder
        else setField field now builder
