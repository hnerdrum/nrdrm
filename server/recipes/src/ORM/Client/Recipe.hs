{-# LANGUAGE TypeApplications #-}

module ORM.Client.Recipe
  ( findAll,
    findMany,
    findUnique,
    findUniqueOrError,
    create,
    update,
    delete,
    withIngredients,
    noInclude,
  )
where

import Control.Monad (forM_)
import Data.Maybe (mapMaybe)
import Data.Pool (Pool)
import Data.Time (UTCTime, getCurrentTime)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as V4
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.ToField (toField)
import Database.Recipe
  ( CreateRecipeIngredientInput (..),
    CreateRecipeInput (..),
    UpdateRecipeIngredientInput (..),
    UpdateRecipeInput (..),
  )
import ORM.Core (NullableValue (..), fieldColumn)
import qualified ORM.Delete as Delete
import ORM.Errors (ORMError)
import qualified ORM.Include as Include
import qualified ORM.Insert as Insert
import qualified ORM.Operations as Ops
import ORM.Query (QueryBuilder)
import ORM.Schema.Recipe (RecipeCreate (..), RecipeRow, RecipeTable, RecipeUpdate (..))
import ORM.Schema.RecipeInclude (RecipeInclude (..), RecipeIngredientInclude (..), RecipeWithIngredients (..))
import ORM.Schema.RecipeIngredient (RecipeIngredientCreate (..), RecipeIngredientTable, recipeIngredientRecipeId)
import ORM.Transaction (transaction)
import qualified ORM.Update as Update

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
  CreateRecipeInput ->
  IO (Either ORMError RecipeWithIngredients)
create pool include input = do
  recipeId <- V4.nextRandom
  transaction pool $ \conn -> do
    recipeResult <-
      Insert.insertConn @RecipeTable @RecipeRow conn (toRecipeCreate recipeId input)
    case recipeResult of
      Left err -> pure (Left err)
      Right _ -> do
        forM_ input.ingredients $ \ingredient ->
          Insert.executeInsertConn conn $
            Insert.toInsertBuilder @RecipeIngredientTable (toRecipeIngredientCreate recipeId ingredient)
        Include.findUniqueOrErrorConn @RecipeTable conn include recipeId

update ::
  Pool Connection ->
  RecipeInclude ->
  UUID ->
  UpdateRecipeInput ->
  IO (Either ORMError RecipeWithIngredients)
update pool include recipeId input = do
  now <- getCurrentTime
  transaction pool $ \conn -> do
    updateResult <-
      Update.updateConn @RecipeTable @RecipeRow conn recipeId (toRecipeUpdate now input)
    case updateResult of
      Left err -> pure (Left err)
      Right _ -> do
        case input.ingredients of
          Nothing -> pure ()
          Just ingredients -> do
            _ <-
              Delete.deleteConn conn $
                Delete.whereDelete (fieldColumn recipeIngredientRecipeId <> " = ?") [toField recipeId] (Delete.emptyDelete @RecipeIngredientTable)
            forM_ (mapMaybe (toRecipeIngredientUpdate recipeId) ingredients) $ \ri ->
              Insert.executeInsertConn conn $
                Insert.toInsertBuilder @RecipeIngredientTable ri
        Include.findUniqueOrErrorConn @RecipeTable conn include recipeId

delete :: Pool Connection -> UUID -> IO ()
delete pool recipeId = do
  _ <- Ops.delete @RecipeTable pool recipeId
  pure ()

toRecipeCreate :: UUID -> CreateRecipeInput -> RecipeCreate
toRecipeCreate recipeId input =
  RecipeCreate
    { id = Just recipeId,
      createdAt = Nothing,
      updatedAt = Nothing,
      name = input.name,
      description = Value input.description
    }

toRecipeUpdate :: UTCTime -> UpdateRecipeInput -> RecipeUpdate
toRecipeUpdate now input =
  RecipeUpdate
    { name = input.name,
      createdAt = Nothing,
      updatedAt = Just now,
      description = maybe Omit Value input.description
    }

toRecipeIngredientCreate :: UUID -> CreateRecipeIngredientInput -> RecipeIngredientCreate
toRecipeIngredientCreate recipeId input =
  RecipeIngredientCreate
    { recipeId,
      ingredientId = input.id,
      amount = input.amount,
      unit = input.unit
    }

toRecipeIngredientUpdate :: UUID -> UpdateRecipeIngredientInput -> Maybe RecipeIngredientCreate
toRecipeIngredientUpdate recipeId input = do
  amount <- input.amount
  unit <- input.unit
  pure
    RecipeIngredientCreate
      { recipeId,
        ingredientId = input.id,
        amount,
        unit
      }
