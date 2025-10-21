{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Update
  ( UpdateBuilder,
    update,
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
import ORM.Core (Entity (..), Field (..))
import ORM.Errors (ORMError (..))

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
  (Entity table, FromRow result) =>
  Pool Connection ->
  UpdateBuilder table ->
  IO (Either ORMError result)
update pool builder = do
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
    let setClause = Text.intercalate ", " $ map (\(col, _) -> col <> " = ?") (ubSets builder)
        setParams = map snd (ubSets builder)
        whereClause =
          if null (ubWhere builder)
            then ""
            else " WHERE " <> Text.intercalate " AND " (ubWhere builder)
        allParams = setParams ++ ubWhereParams builder
        queryText =
          "UPDATE "
            <> ubTable builder
            <> " SET "
            <> setClause
            <> whereClause
            <> " RETURNING *"
        query = Query (TE.encodeUtf8 queryText)
    PGSimple.queryWith fromRow conn query allParams
