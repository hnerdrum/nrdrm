{-# LANGUAGE TypeApplications #-}

module ORM.Client.Recipe
  ( findAllWithIngredients,
    findUniqueWithIngredients,
    findUniqueOrError,
    create,
    update,
    delete,
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
import ORM.Errors (ORMError (..))
import ORM.Include (findManyWith)
import qualified ORM.Insert as Insert
import qualified ORM.Operations as Ops
import ORM.Query (whereEq)
import ORM.Schema.Recipe
  ( RecipeCreate (..),
    RecipeRow,
    RecipeTable,
    RecipeUpdate (..),
  )
import qualified ORM.Schema.Recipe as Recipe
import ORM.Schema.RecipeInclude
  ( RecipeWithIngredients (..),
    recipeIngredientsInclude,
  )
import ORM.Schema.RecipeIngredient
  ( RecipeIngredientCreate (..),
    RecipeIngredientTable,
    riRecipeId,
  )
import qualified ORM.Update as Update

findAllWithIngredients :: Pool Connection -> IO [RecipeWithIngredients]
findAllWithIngredients pool =
  findManyWith @RecipeTable pool recipeIngredientsInclude Prelude.id

findUniqueWithIngredients :: Pool Connection -> UUID -> IO (Maybe RecipeWithIngredients)
findUniqueWithIngredients pool pk = do
  results <-
    findManyWith @RecipeTable pool recipeIngredientsInclude (whereEq Recipe.recipeId pk)
  case results of
    [recipe] -> pure (Just recipe)
    [] -> pure Nothing
    _ -> error "findUniqueWithIngredients: multiple recipes matched primary key"

create ::
  Pool Connection ->
  CreateRecipeInput ->
  IO (Either ORMError RecipeWithIngredients)
create pool input = do
  recipeId <- V4.nextRandom
  recipeResult <-
    Insert.insert @RecipeTable @RecipeRow pool (toRecipeCreate recipeId input)
  case recipeResult of
    Left err -> pure (Left err)
    Right _ -> do
      forM_ input.ingredients $ \ingredient ->
        Insert.executeInsert pool $
          Insert.toInsertBuilder @RecipeIngredientTable (toRecipeIngredientCreate recipeId ingredient)
      findUniqueOrError pool recipeId

update ::
  Pool Connection ->
  UUID ->
  UpdateRecipeInput ->
  IO (Either ORMError RecipeWithIngredients)
update pool recipeId input = do
  now <- getCurrentTime
  updateResult <-
    Update.update @RecipeTable @RecipeRow pool recipeId (toRecipeUpdate now input)
  case updateResult of
    Left err -> pure (Left err)
    Right _ -> do
      case input.ingredients of
        Nothing -> pure ()
        Just ingredients -> do
          _ <-
            Delete.delete pool $
              Delete.whereDelete (fieldColumn riRecipeId <> " = ?") [toField recipeId] (Delete.emptyDelete @RecipeIngredientTable)
          forM_ (mapMaybe (toRecipeIngredientUpdate recipeId) ingredients) $ \ri ->
            Insert.executeInsert pool $
              Insert.toInsertBuilder @RecipeIngredientTable ri
      findUniqueOrError pool recipeId

delete :: Pool Connection -> UUID -> IO ()
delete pool recipeId = do
  _ <- Ops.delete @RecipeTable pool recipeId
  pure ()

findUniqueOrError ::
  Pool Connection ->
  UUID ->
  IO (Either ORMError RecipeWithIngredients)
findUniqueOrError pool pk = do
  mRecipe <- findUniqueWithIngredients pool pk
  case mRecipe of
    Nothing -> pure $ Left $ RecordNotFound "Recipe could not be found"
    Just recipe -> pure $ Right recipe

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
