{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Recipe
    (
      RecipeAPI
      , getAllRecipesHandler
      , getRecipeHandler
      , createRecipeHandler
      , deleteRecipeHandler
    ) where

import Control.Monad.Reader (asks, liftIO)
import Data.UUID
import Database.Recipe (CreateRecipeInput(..))
import Domain.Recipe (Recipe(..), getAllRecipes, getRecipe, RecipeError(..), createRecipe, deleteRecipe)
import App (AppContext(..), AppM)
import Servant

type RecipeAPI =
       "recipes" :> Get '[JSON] [Recipe]
  :<|> "recipes" :> Capture "recipeId" UUID :> Get '[JSON] Recipe
  :<|> "recipes" :> ReqBody '[JSON] CreateRecipeInput :> PostNoContent
  :<|> "recipes" :> Capture "recipeId" UUID :> DeleteNoContent

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

createRecipeHandler :: CreateRecipeInput -> AppM NoContent
createRecipeHandler createRecipeInput = do
  pool <- asks dbPool
  _ <- liftIO $ createRecipe pool createRecipeInput
  return NoContent

deleteRecipeHandler :: UUID -> AppM NoContent
deleteRecipeHandler recipeId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent

fromRecipeDbError :: RecipeError -> ServerError
fromRecipeDbError recipeDbError
  | recipeDbError == RecipeNotFound = err404 { errBody = "Recipe could not be found" }
  | otherwise                       = err500 { errBody = "Found multiple recipes with matching ID" }
