{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module ORM.Insert
  ( InsertBuilder,
    Insertable (..),
    insert,
    insertConn,
    insertBuilder,
    insertBuilderConn,
    insertReturning,
    insertReturningConn,
    executeInsert,
    executeInsertConn,
    emptyInsert,
    set,
    setNull,
    setMaybe,
    setNullable,
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
import ORM.Core (Entity (..), Field (..), NullableValue (..))
import ORM.Errors (ORMError (..))
import ORM.Sql (catchSql)

class (Entity table) => Insertable table where
  type CreateInput table
  toInsertBuilder :: CreateInput table -> InsertBuilder table

data InsertBuilder table = InsertBuilder
  { ibTable :: Text,
    ibColumns :: [Text],
    ibValues :: [Action]
  }

insert ::
  forall table result.
  (Insertable table, FromRow result) =>
  Pool Connection ->
  CreateInput table ->
  IO (Either ORMError result)
insert pool input =
  withResource pool $ \conn -> insertConn @table @result conn input

insertConn ::
  forall table result.
  (Insertable table, FromRow result) =>
  Connection ->
  CreateInput table ->
  IO (Either ORMError result)
insertConn conn input =
  insertBuilderConn conn (toInsertBuilder @table input)

insertBuilder ::
  forall table result.
  (FromRow result) =>
  Pool Connection ->
  InsertBuilder table ->
  IO (Either ORMError result)
insertBuilder pool builder =
  withResource pool $ \conn -> insertBuilderConn conn builder

insertBuilderConn ::
  forall table result.
  (FromRow result) =>
  Connection ->
  InsertBuilder table ->
  IO (Either ORMError result)
insertBuilderConn conn builder = do
  result <- catchSql (insertReturningConn conn builder)
  case result of
    Left err -> pure $ Left err
    Right [] ->
      pure $
        Left $
          RecordNotFound $
            "INSERT into " <> ibTable builder <> " returned no rows"
    Right [row] -> pure $ Right row
    Right _ -> pure $ Left $ MultipleRecordsFound "Insert returned multiple rows"

insertReturning ::
  forall table result.
  (FromRow result) =>
  Pool Connection ->
  InsertBuilder table ->
  IO [result]
insertReturning pool builder =
  withResource pool $ \conn -> insertReturningConn conn builder

insertReturningConn ::
  forall table result.
  (FromRow result) =>
  Connection ->
  InsertBuilder table ->
  IO [result]
insertReturningConn conn builder = do
  let allColumns = ibColumns builder
      allValues = ibValues builder
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

executeInsert ::
  Pool Connection ->
  InsertBuilder table ->
  IO ()
executeInsert pool builder =
  withResource pool $ \conn -> executeInsertConn conn builder

executeInsertConn ::
  Connection ->
  InsertBuilder table ->
  IO ()
executeInsertConn conn builder = do
  let allColumns = ibColumns builder
      allValues = ibValues builder
      placeholders = Text.intercalate ", " $ replicate (length allValues) "?"
      columnsText = Text.intercalate ", " allColumns
      queryText =
        "INSERT INTO "
          <> ibTable builder
          <> " ("
          <> columnsText
          <> ") VALUES ("
          <> placeholders
          <> ")"
      query = Query (TE.encodeUtf8 queryText)
  _ <- PGSimple.execute conn query allValues
  pure ()

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

setNull ::
  forall table a.
  (ToField (Maybe a)) =>
  Field table a ->
  InsertBuilder table ->
  InsertBuilder table
setNull field builder =
  builder
    { ibColumns = ibColumns builder ++ [fieldColumn field],
      ibValues = ibValues builder ++ [toField (Nothing :: Maybe a)]
    }

setMaybe ::
  forall table a.
  (ToField a) =>
  Field table a ->
  Maybe a ->
  InsertBuilder table ->
  InsertBuilder table
setMaybe _ Nothing builder = builder
setMaybe field (Just value) builder = set field value builder

setNullable ::
  forall table a.
  (ToField a, ToField (Maybe a)) =>
  Field table a ->
  NullableValue a ->
  InsertBuilder table ->
  InsertBuilder table
setNullable _ Omit builder = builder
setNullable field (Value value) builder = set field value builder
setNullable field Null builder = setNull field builder
