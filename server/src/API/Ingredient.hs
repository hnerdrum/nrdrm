{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Ingredient
  ( getAllIngredientsHandler
  , getIngredientHandler
  , createIngredientHandler
  ) where

import API.Errors (ToServantError (toServerError))
import API.Utils (handleEither)
import App (AppContext(..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Text
import Data.UUID
import Database.Ingredient (Ingredient(..), CreateIngredientInput(..))
import Domain.Errors (IngredientError(..))
import Domain.Ingredient (getAllIngredients, getIngredient, createIngredient)
import Katip (LogEnv, Namespace)
import Logger (logInfo, logError)
import Servant

getAllIngredientsHandler :: AppM [Ingredient]
getAllIngredientsHandler = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "getAllIngredientsHandler" "[GET] /api/v1/ingredients"
  liftIO $ getAllIngredients pool

getIngredientHandler :: UUID -> AppM Ingredient
getIngredientHandler ingredientId = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "getIngredientHandler" $ "[GET] /api/v1/ingredients/" <> (pack . show) ingredientId
  eitherIngredient <- liftIO $ getIngredient pool ingredientId
  handleEither (handleError logEnv "getIngredientHandler" ("Ingredient with ID: " <> (pack . show) ingredientId <> " not found")) eitherIngredient

createIngredientHandler :: CreateIngredientInput -> AppM Ingredient
createIngredientHandler createIngredientInput = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "createIngredientHandler" "[POST] /api/v1/ingredients/"
  eitherIngredient <- liftIO $ createIngredient pool createIngredientInput
  handleEither (handleError logEnv "createIngredientHandler" "Ingredient not found") eitherIngredient

handleError :: LogEnv -> Namespace -> Text -> IngredientError -> AppM Ingredient
handleError logEnv namespace message err = do
          liftIO $ logError logEnv namespace message
          throwError $ toServerError err