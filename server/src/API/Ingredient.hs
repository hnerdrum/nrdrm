{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Ingredient
  ( getAllIngredientsHandler
  ) where

import Control.Monad.Reader (asks, liftIO)
import App (AppContext(..), AppM)
import Database.Ingredient (Ingredient(..))
import Domain.Ingredient (getAllIngredients)
import Logger (logInfo)

getAllIngredientsHandler :: AppM [Ingredient]
getAllIngredientsHandler = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "getAllIngredientsHandler" "[GET] /api/v1/ingredients"
  liftIO $ getAllIngredients pool