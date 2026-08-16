{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Client.Ingredient
  ( create,
    update,
    findMany,
    findUnique,
    findUniqueOrFail,
    delete,
    deleteMany,
    IngredientQuery (..),
    emptyQuery,
  )
where

import Data.UUID (UUID)
import ORM.Db (Db)
import qualified ORM.Delete as Delete
import ORM.Errors (ORMError)
import qualified ORM.Insert as Insert
import qualified ORM.Operations as Ops
import ORM.Query (QueryBuilder, applyQueryModifiers)
import ORM.Schema.Ingredient (IngredientCreate, IngredientRow, IngredientTable, IngredientUpdate)
import qualified ORM.Update as Update

create :: IngredientCreate -> Db (Either ORMError IngredientRow)
create = Insert.insert @IngredientTable @IngredientRow

update :: UUID -> IngredientUpdate -> Db (Either ORMError IngredientRow)
update = Update.update @IngredientTable @IngredientRow

data IngredientQuery = IngredientQuery
  { where_ :: Maybe (QueryBuilder IngredientTable -> QueryBuilder IngredientTable),
    orderBy_ :: Maybe (QueryBuilder IngredientTable -> QueryBuilder IngredientTable),
    limit_ :: Maybe Int,
    offset_ :: Maybe Int
  }

emptyQuery :: IngredientQuery
emptyQuery =
  IngredientQuery {where_ = Nothing, orderBy_ = Nothing, limit_ = Nothing, offset_ = Nothing}

findMany :: IngredientQuery -> Db [IngredientRow]
findMany q =
  Ops.findMany @IngredientTable @IngredientRow (applyQuery q)

applyQuery :: IngredientQuery -> QueryBuilder IngredientTable -> QueryBuilder IngredientTable
applyQuery IngredientQuery {..} =
  applyQueryModifiers where_ orderBy_ limit_ offset_

findUnique :: UUID -> Db (Maybe IngredientRow)
findUnique = Ops.findUnique @IngredientTable @IngredientRow

findUniqueOrFail :: UUID -> Db (Either ORMError IngredientRow)
findUniqueOrFail = Ops.findUniqueOrError @IngredientTable @IngredientRow

delete :: UUID -> Db Int
delete = Ops.deleteById @IngredientTable

deleteMany :: (QueryBuilder IngredientTable -> QueryBuilder IngredientTable) -> Db Int
deleteMany = Delete.deleteMany @IngredientTable
