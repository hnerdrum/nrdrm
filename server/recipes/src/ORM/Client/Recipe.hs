{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Client.Recipe
  ( findAll,
    findMany,
    findUnique,
    findUniqueOrError,
    create,
    update,
    delete,
    RecipeWriteCreate (..),
    RecipeWriteUpdate (..),
    RecipeIngredientNestedCreate (..),
    withIngredients,
    noInclude
  )

where

import Control.Monad (forM_)
import Data.Pool (Pool)
import Data.Time (UTCTime, getCurrentTime)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as V4
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.ToField (toField)
import ORM.Core (fieldColumn)
import qualified ORM.Delete as Delete
import ORM.Errors (ORMError)
import qualified ORM.Include as Include
import qualified ORM.Insert as Insert
import ORM.Schema.Recipe ( RecipeCreate (..), RecipeRow, RecipeTable, RecipeUpdate (..))
import ORM.Schema.RecipeInclude ( RecipeInclude (..), RecipeIngredientInclude (..), RecipeWithIngredients (..))
import ORM.Schema.RecipeIngredient ( RecipeIngredientCreate (..), RecipeIngredientTable, recipeIngredientRecipeId)
import ORM.Transaction (transaction)
import qualified ORM.Operations as Ops
import ORM.Query (QueryBuilder)
import qualified ORM.Update as Update
import ORM.Schema.Unit (Unit)

data RecipeWriteCreate = RecipeWriteCreate
  { root :: RecipeCreate
  , ingredients :: [RecipeIngredientNestedCreate]
  }
  deriving (Show, Eq)

data RecipeIngredientNestedCreate = RecipeIngredientNestedCreate
  { ingredientId :: UUID, amount :: Int, unit :: Unit
  }
  deriving (Show, Eq)



data RecipeWriteUpdate = RecipeWriteUpdate
  { root :: RecipeUpdate
  , ingredients :: Maybe [RecipeIngredientNestedCreate]
  }
  deriving (Show, Eq)


toRecipeIngredientCreate :: UUID -> RecipeIngredientNestedCreate -> RecipeIngredientCreate
toRecipeIngredientCreate parentId nested =
  RecipeIngredientCreate
    { id = Nothing,
      ingredientId = nested.ingredientId,
      amount = nested.amount,
      unit = nested.unit,
      recipeId = parentId
    }


applyUpdatedAt :: UTCTime -> RecipeUpdate -> RecipeUpdate
applyUpdatedAt now input = input { updatedAt = Just now }


withIngredients :: RecipeInclude
withIngredients =
  RecipeInclude {ingredients = Just (RecipeIngredientInclude {ingredient = True})}


noInclude :: RecipeInclude
noInclude = RecipeInclude {ingredients = Nothing}


findAll :: Pool Connection -> RecipeInclude -> IO [RecipeWithIngredients]
findAll = Include.findAll @RecipeTable


findMany ::
  Pool Connection ->
  RecipeInclude ->
  (QueryBuilder RecipeTable -> QueryBuilder RecipeTable) ->
  IO [RecipeWithIngredients]
findMany = Include.findMany @RecipeTable


findUnique :: Pool Connection -> RecipeInclude -> UUID -> IO (Maybe RecipeWithIngredients)
findUnique = Include.findUnique @RecipeTable


findUniqueOrError :: Pool Connection -> RecipeInclude -> UUID -> IO (Either ORMError RecipeWithIngredients)
findUniqueOrError = Include.findUniqueOrError @RecipeTable


create ::
  Pool Connection ->
  RecipeInclude ->
  RecipeWriteCreate ->
  IO (Either ORMError RecipeWithIngredients)
create pool include input = do
  rootId <- maybe V4.nextRandom pure input.root.id
  let rootInput :: RecipeCreate
      rootInput = input.root { id = Just rootId }
  transaction pool $ \conn -> do
    rootResult <-
      Insert.insertConn @RecipeTable @RecipeRow conn rootInput
    case rootResult of
      Left err -> pure (Left err)
      Right _ -> do
        forM_ input.ingredients $ \nested ->
          Insert.executeInsertConn conn $
            Insert.toInsertBuilder @RecipeIngredientTable (toRecipeIngredientCreate rootId nested)
        Include.findUniqueOrErrorConn @RecipeTable conn include rootId


update ::
  Pool Connection ->
  RecipeInclude ->
  UUID ->
  RecipeWriteUpdate ->
  IO (Either ORMError RecipeWithIngredients)
update pool include rootId input = do
  now <- getCurrentTime
  transaction pool $ \conn -> do
    updateResult <-
      Update.updateConn @RecipeTable @RecipeRow conn rootId (applyUpdatedAt now input.root)
    case updateResult of
      Left err -> pure (Left err)
      Right _ -> do
        case input.ingredients of
          Nothing -> pure ()
          Just nestedItems -> do
            _ <-
              Delete.deleteConn conn $
                Delete.whereDelete (fieldColumn recipeIngredientRecipeId <> " = ?") [toField rootId] (Delete.emptyDelete @RecipeIngredientTable)
            forM_ nestedItems $ \nested ->
              Insert.executeInsertConn conn $
                Insert.toInsertBuilder @RecipeIngredientTable (toRecipeIngredientCreate rootId nested)
        Include.findUniqueOrErrorConn @RecipeTable conn include rootId


delete :: Pool Connection -> UUID -> IO Int
delete = Ops.delete @RecipeTable

