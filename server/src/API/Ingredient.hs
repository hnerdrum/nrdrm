{-# LANGUAGE DataKinds       #-}

module API.Ingredient
  ( getAllIngredientsHandler
  ) where

import Control.Monad.Reader (asks, liftIO)
import App (AppContext(..), AppM)
import Database.Ingredient (Ingredient(..))
import Domain.Ingredient (getAllIngredients)

getAllIngredientsHandler :: AppM [Ingredient]
getAllIngredientsHandler = do
  pool <- asks dbPool
  liftIO $ getAllIngredients pool