{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Recipe
    ( getAllRecipesHandler
    , getRecipeHandler
    , createRecipeHandler
    , updateRecipeHandler
    , deleteRecipeHandler
    ) where

import API.Errors (ToServantError (toServerError))
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
  case eitherRecipe of
    Right r -> return r
    Left err -> throwError $ toServerError err

createRecipeHandler :: CreateRecipeInput -> AppM Recipe
createRecipeHandler createRecipeInput = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "createRecipeHandler" "[POST] /api/v1/recipes/"
  eitherRecipe <- liftIO $ createRecipe pool createRecipeInput
  case eitherRecipe of
    Right r -> return r
    Left err -> throwError $ toServerError err

updateRecipeHandler :: UUID -> UpdateRecipeInput -> AppM Recipe
updateRecipeHandler recipeId updateRecipeInput = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "updateRecipeHandler" "[PUT] /api/v1/recipes/"
  eitherRecipe <- liftIO $ updateRecipe pool recipeId updateRecipeInput
  case eitherRecipe of
    Right r -> return r
    Left err -> throwError $ toServerError err

deleteRecipeHandler :: UUID -> AppM NoContent
deleteRecipeHandler recipeId = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "deleteRecipeHandler" $ "[DELETE] /api/v1/recipes/" <> (pack . show) recipeId
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent
