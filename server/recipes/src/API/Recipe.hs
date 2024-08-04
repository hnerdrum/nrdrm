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
import Servant

getAllRecipesHandler :: AppM [Recipe]
getAllRecipesHandler = do
  pool <- asks dbPool
  liftIO $ getAllRecipes pool

getRecipeHandler :: UUID -> AppM Recipe
getRecipeHandler recipeId = do
  pool <- asks dbPool
  eitherRecipe <- liftIO $ getRecipe pool recipeId
  resolveEitherAppResult (handleError "getRecipeHandler" ("Recipe with ID: " <> (pack . show) recipeId <> " not found")) return eitherRecipe

createRecipeHandler :: CreateRecipeInput -> AppM Recipe
createRecipeHandler createRecipeInput = do
  pool <- asks dbPool
  eitherRecipe <- liftIO $ createRecipe pool createRecipeInput
  resolveEitherAppResult (handleError "createRecipeHandler" "Recipe not found") return eitherRecipe

updateRecipeHandler :: UUID -> UpdateRecipeInput -> Maybe Text -> AppM Recipe
updateRecipeHandler = authMiddleware . updateRecipeUnsafe

updateRecipeUnsafe :: UUID -> UpdateRecipeInput -> AppM Recipe
updateRecipeUnsafe recipeId updateRecipeInput = do
  pool <- asks dbPool
  eitherRecipe <- liftIO $ updateRecipe pool recipeId updateRecipeInput
  resolveEitherAppResult (handleError "updateRecipeHandler" ("Recipe with ID: " <> (pack . show) recipeId <> " not found")) return eitherRecipe

deleteRecipeHandler :: UUID -> Maybe Text -> AppM NoContent
deleteRecipeHandler = authMiddleware deleteRecipeUnsafe

deleteRecipeUnsafe :: UUID -> AppM NoContent
deleteRecipeUnsafe recipeId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent
