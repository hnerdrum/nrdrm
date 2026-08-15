{-# LANGUAGE TypeApplications #-}

module ORM.Client.Ingredient
  ( create,
    createConn,
    update,
    updateConn,
    findAll,
    findAllConn,
    findUnique,
    findUniqueConn,
    findUniqueOrError,
    findUniqueOrErrorConn,
    deleteById,
    deleteByIdConn
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


createConn :: Connection -> IngredientCreate -> IO (Either ORMError IngredientRow)
createConn = Insert.insertConn @IngredientTable @IngredientRow


update :: Pool Connection -> UUID -> IngredientUpdate -> IO (Either ORMError IngredientRow)
update = Update.update @IngredientTable @IngredientRow


updateConn :: Connection -> UUID -> IngredientUpdate -> IO (Either ORMError IngredientRow)
updateConn = Update.updateConn @IngredientTable @IngredientRow


findAll :: Pool Connection -> IO [IngredientRow]
findAll = Ops.findAll @IngredientTable @IngredientRow


findAllConn :: Connection -> IO [IngredientRow]
findAllConn = Ops.findAllConn @IngredientTable @IngredientRow


findUnique :: Pool Connection -> UUID -> IO (Maybe IngredientRow)
findUnique = Ops.findUnique @IngredientTable @IngredientRow


findUniqueConn :: Connection -> UUID -> IO (Maybe IngredientRow)
findUniqueConn = Ops.findUniqueConn @IngredientTable @IngredientRow


findUniqueOrError :: Pool Connection -> UUID -> IO (Either ORMError IngredientRow)
findUniqueOrError = Ops.findUniqueOrError @IngredientTable @IngredientRow


findUniqueOrErrorConn :: Connection -> UUID -> IO (Either ORMError IngredientRow)
findUniqueOrErrorConn = Ops.findUniqueOrErrorConn @IngredientTable @IngredientRow


deleteById :: Pool Connection -> UUID -> IO Int
deleteById = Ops.deleteById @IngredientTable


deleteByIdConn :: Connection -> UUID -> IO Int
deleteByIdConn = Ops.deleteByIdConn @IngredientTable

