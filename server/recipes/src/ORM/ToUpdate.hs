{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.ToUpdate
  ( ToUpdate (..),
    updateWith,
  )
where

import Data.Pool (Pool)
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField, toField)
import ORM.Core (Entity (..), Field (..), PrimaryKeyType)
import ORM.Errors (ORMError)
import qualified ORM.Update as Update

class ToUpdate input table where
  toUpdateBuilder :: input -> Update.UpdateBuilder table

updateWith ::
  forall input table result.
  ( ToUpdate input table,
    Entity table,
    FromRow result,
    ToField (PrimaryKeyType table)
  ) =>
  Pool Connection ->
  PrimaryKeyType table ->
  input ->
  IO (Either ORMError result)
updateWith pool pkValue inputData = do
  let builder = toUpdateBuilder @input @table inputData
      pkField = primaryKey @table
      builderWithWhere = Update.whereUpdate (fieldColumn pkField <> " = ?") [toField pkValue] builder
  Update.update pool builderWithWhere
