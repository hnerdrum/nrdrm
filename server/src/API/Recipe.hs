{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}

module API.Recipe
    (
      RecipeAPI
      , recipes
    ) where

import Control.Monad.Reader (asks, liftIO)
import Domain.Recipe (Recipe(..), getAllRecipes)
import App (AppContext(..), AppM)
import Network.Wai
import Servant

type RecipeAPI = "recipes" :> Get '[JSON] [Recipe]

recipes :: AppM [Recipe]
recipes = do
  pool <- asks dbPool
  liftIO $ getAllRecipes pool