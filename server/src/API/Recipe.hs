{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Recipe
    ( getAllRecipesHandler
    , getRecipeHandler
    , createRecipeHandler
    , updateRecipeHandler
    , deleteRecipeHandler
    ) where

import API.Auth (authMiddleware)
import API.Errors (handleError)
import API.Utils (resolveEitherAppResult)
import App (AppContext(..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.UUID
import Data.Text
import Database.Recipe (CreateRecipeInput(..), UpdateRecipeInput(..))
import Domain.Recipe (Recipe(..), getAllRecipes, getRecipe, createRecipe, updateRecipe, deleteRecipe)
import Logger (logInfo)
import Servant

getAllRecipesHandler :: AppM [Recipe]
getAllRecipesHandler = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "getAllRecipesHandler" "[GET] /api/v1/recipes"
  liftIO $ getAllRecipes pool

getRecipeHandler :: UUID -> AppM Recipe
getRecipeHandler recipeId = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "getRecipeHandler" $ "[GET] /api/v1/recipes/" <> (pack . show) recipeId
  eitherRecipe <- liftIO $ getRecipe pool recipeId
  resolveEitherAppResult (handleError "getRecipeHandler" ("Recipe with ID: " <> (pack . show) recipeId <> " not found")) return eitherRecipe

createRecipeHandler :: CreateRecipeInput -> AppM Recipe
createRecipeHandler createRecipeInput = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "createRecipeHandler" "[POST] /api/v1/recipes/"
  eitherRecipe <- liftIO $ createRecipe pool createRecipeInput
  resolveEitherAppResult (handleError "createRecipeHandler" "Recipe not found") return eitherRecipe

updateRecipeHandler :: UUID -> UpdateRecipeInput -> AppM Recipe
updateRecipeHandler recipeId updateRecipeInput = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "updateRecipeHandler" "[PUT] /api/v1/recipes/"
  eitherRecipe <- liftIO $ updateRecipe pool recipeId updateRecipeInput
  resolveEitherAppResult (handleError "updateRecipeHandler" ("Recipe with ID: " <> (pack . show) recipeId <> " not found")) return eitherRecipe

deleteRecipeHandler :: UUID -> Maybe Text -> AppM NoContent
deleteRecipeHandler  = authMiddleware deleteRecipeUnsafe

deleteRecipeUnsafe :: UUID -> AppM NoContent
deleteRecipeUnsafe recipeId = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "deleteRecipeHandler" $ "[DELETE] /api/v1/recipes/" <> (pack . show) recipeId
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent
