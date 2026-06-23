{-# LANGUAGE TypeApplications #-}

module ORM.Client.Ingredient
  ( create,
    update,
    findAll,
    findUnique,
    findUniqueOrError,
    delete,
  )
where

import Data.Pool (Pool)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple (Connection)
import ORM.Errors (ORMError)
import qualified ORM.Insert as Insert
import qualified ORM.Operations as Ops
import ORM.Schema.Ingredient (IngredientCreate, IngredientRow, IngredientTable, IngredientUpdate)
import qualified ORM.Update as Update

create :: Pool Connection -> IngredientCreate -> IO (Either ORMError IngredientRow)
create = Insert.insert @IngredientTable @IngredientRow

update :: Pool Connection -> UUID -> IngredientUpdate -> IO (Either ORMError IngredientRow)
update = Update.update @IngredientTable @IngredientRow

findAll :: Pool Connection -> IO [IngredientRow]
findAll = Ops.findAll @IngredientTable @IngredientRow

findUnique :: Pool Connection -> UUID -> IO (Maybe IngredientRow)
findUnique = Ops.findUnique @IngredientTable @IngredientRow

findUniqueOrError :: Pool Connection -> UUID -> IO (Either ORMError IngredientRow)
findUniqueOrError = Ops.findUniqueOrError @IngredientTable @IngredientRow

delete :: Pool Connection -> UUID -> IO Int
delete = Ops.delete @IngredientTable
