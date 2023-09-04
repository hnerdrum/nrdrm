{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Recipe
    ( getAllRecipesHandler
    , getRecipeHandler
    , createRecipeHandler
    , updateRecipeHandler
    , deleteRecipeHandler
    ) where

import Control.Monad.Reader (asks, liftIO)
import Data.UUID
import Database.Recipe (CreateRecipeInput(..), UpdateRecipeInput(..))
import Domain.Recipe (Recipe(..), getAllRecipes, getRecipe, RecipeError(..), createRecipe, updateRecipe, deleteRecipe)
import App (AppContext(..), AppM)
import Servant

getAllRecipesHandler :: AppM [Recipe]
getAllRecipesHandler = do
  pool <- asks dbPool
  liftIO $ getAllRecipes pool

getRecipeHandler :: UUID -> AppM Recipe
getRecipeHandler recipeId = do
  pool <- asks dbPool
  eitherRecipe <- liftIO $ getRecipe pool recipeId
  case eitherRecipe of
    Right r -> return r
    Left err -> throwError $ fromRecipeDbError err

createRecipeHandler :: CreateRecipeInput -> AppM Recipe
createRecipeHandler createRecipeInput = do
  pool <- asks dbPool
  eitherRecipe <- liftIO $ createRecipe pool createRecipeInput
  case eitherRecipe of
    Right r -> return r
    Left err -> throwError $ fromRecipeDbError err

updateRecipeHandler :: UUID -> UpdateRecipeInput -> AppM Recipe
updateRecipeHandler recipeId updateRecipeInput = do
  pool <- asks dbPool
  eitherRecipe <- liftIO $ updateRecipe pool recipeId updateRecipeInput
  case eitherRecipe of
    Right r -> return r
    Left err -> throwError $ fromRecipeDbError err

deleteRecipeHandler :: UUID -> AppM NoContent
deleteRecipeHandler recipeId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent

fromRecipeDbError :: RecipeError -> ServerError
fromRecipeDbError recipeDbError
  | recipeDbError == RecipeNotFound       = err404 { errBody = "Recipe could not be found" }
  | recipeDbError == MultipleRecipesFound = err500 { errBody = "Found multiple recipes with matching ID" }
  | otherwise                             = err500 { errBody = "An unexpected error occurred" }
