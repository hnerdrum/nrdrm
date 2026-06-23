{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module ORM.Update
  ( UpdateBuilder,
    Updatable (..),
    update,
    updateBuilder,
    updateReturning,
    setField,
    whereUpdate,
    emptyUpdate,
  )
where

import Data.Pool (Pool, withResource)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple (Connection)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.ToField (Action, ToField, toField)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Core (Entity (..), Field (..), PrimaryKeyType)
import ORM.Errors (ORMError (..))

class (Entity table) => Updatable table where
  type UpdateInput table
  toUpdateBuilder :: UpdateInput table -> UpdateBuilder table

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

whereUpdate :: Text -> [Action] -> UpdateBuilder table -> UpdateBuilder table
whereUpdate condition params builder =
  builder
    { ubWhere = ubWhere builder ++ [condition],
      ubWhereParams = ubWhereParams builder ++ params
    }

update ::
  forall table result.
  (Updatable table, FromRow result, ToField (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  UpdateInput table ->
  IO (Either ORMError result)
update pool pkValue input = do
  let pkField = primaryKey @table
      builderWithWhere =
        whereUpdate
          (fieldColumn pkField <> " = ?")
          [toField pkValue]
          (toUpdateBuilder @table input)
  updateBuilder pool builderWithWhere

updateBuilder ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  UpdateBuilder table ->
  IO (Either ORMError result)
updateBuilder pool builder = do
  results <- updateReturning pool builder
  case results of
    [] -> return $ Left $ RecordNotFound "No record found to update"
    [row] -> return $ Right row
    _ -> return $ Left $ MultipleRecordsFound "Update affected multiple rows"

updateReturning ::
  forall table result.
  (Entity table, FromRow result) =>
  Pool Connection ->
  UpdateBuilder table ->
  IO [result]
updateReturning pool builder =
  withResource pool $ \conn -> do
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