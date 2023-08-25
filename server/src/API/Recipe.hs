{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Recipe
    (
      RecipeAPI
      , recipes
      , recipe
    ) where

import Control.Monad.Reader (asks, liftIO)
import Data.UUID
import Domain.Recipe (Recipe(..), getAllRecipes, getRecipe, RecipeDbError(..))
import App (AppContext(..), AppM)
import Servant

type RecipeAPI =
       "recipes" :> Get '[JSON] [Recipe]
  :<|> "recipes" :> Capture "recipeId" UUID :> Get '[JSON] Recipe

recipes :: AppM [Recipe]
recipes = do
  pool <- asks dbPool
  liftIO $ getAllRecipes pool

recipe :: UUID -> AppM Recipe
recipe recipeId = do
  pool <- asks dbPool
  eitherRecipe <- liftIO $ getRecipe pool recipeId
  case eitherRecipe of
    Right r -> return r
    Left err -> throwError $ fromRecipeDbError err

fromRecipeDbError :: RecipeDbError -> ServerError
fromRecipeDbError recipeDbError
  | recipeDbError == RecipeNotFound = err404 { errBody = "Recipe could not be found" }
  | otherwise                       = err500 { errBody = "Found multiple recipes with matching ID" }
