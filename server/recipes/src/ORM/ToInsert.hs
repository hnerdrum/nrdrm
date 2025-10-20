{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.ToInsert
  ( ToInsert (..),
    createWith,
  )
where

import Data.Pool (Pool)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as V4
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.FromRow (FromRow)
import ORM.Core (Entity (..), PrimaryKeyType)
import ORM.Errors (ORMError)
import qualified ORM.Insert as Insert

class ToInsert input table where
  toInsertBuilder :: input -> Insert.InsertBuilder table

createWith ::
  forall input table result.
  ( ToInsert input table,
    Entity table,
    FromRow result,
    PrimaryKeyType table ~ UUID,
    Show (PrimaryKeyType table)
  ) =>
  Pool Connection ->
  input ->
  IO (Either ORMError result)
createWith pool inputData = do
  pkValue <- V4.nextRandom
  let builder = toInsertBuilder @input @table inputData
  Insert.insert pool pkValue builder
