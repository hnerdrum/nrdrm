{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Insert
  ( InsertBuilder,
    insert,
    insertReturning,
    set,
    setValue,
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

data InsertBuilder table = InsertBuilder
  { ibTable :: Text,
    ibColumns :: [Text],
    ibValues :: [Action]
  }

insert ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table), Show (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  InsertBuilder table ->
  IO (Either ORMError result)
insert pool pkValue builder = do
  result <- insertReturning pool pkValue builder
  case result of
    [] -> return $ Left $ RecordNotFound $ "Insert failed for primary key: " <> (Text.pack . show) pkValue
    [row] -> return $ Right row
    _ -> return $ Left $ MultipleRecordsFound "Insert returned multiple rows"

insertReturning ::
  forall table result.
  (Entity table, FromRow result, ToField (PrimaryKeyType table)) =>
  Pool Connection ->
  PrimaryKeyType table ->
  InsertBuilder table ->
  IO [result]
insertReturning pool pkValue builder =
  withResource pool $ \conn -> do
    let pkField = primaryKey @table
        allColumns = fieldColumn pkField : ibColumns builder
        allValues = toField pkValue : ibValues builder
        placeholders = Text.intercalate ", " $ replicate (length allValues) "?"
        columnsText = Text.intercalate ", " allColumns
        queryText =
          "INSERT INTO "
            <> ibTable builder
            <> " ("
            <> columnsText
            <> ") VALUES ("
            <> placeholders
            <> ") RETURNING *"
        query = Query (TE.encodeUtf8 queryText)
    PGSimple.queryWith fromRow conn query allValues

emptyInsert :: forall table. (Entity table) => InsertBuilder table
emptyInsert =
  InsertBuilder
    { ibTable = tableName @table,
      ibColumns = [],
      ibValues = []
    }

set :: forall table a. (ToField a) => Field table a -> a -> InsertBuilder table -> InsertBuilder table
set field value builder =
  builder
    { ibColumns = ibColumns builder ++ [fieldColumn field],
      ibValues = ibValues builder ++ [toField value]
    }

setValue :: forall table a. (Entity table, ToField a) => Field table a -> a -> InsertBuilder table
setValue field value = set field value (emptyInsert @table)
