module API.Recipe
  ( getAllRecipesRoute,
    getRecipeRoute,
    createRecipeRoute,
    updateRecipeRoute,
    deleteRecipeHandler,
  )
where

import API.Errors (withErrorHandling)
import App (AppContext (..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.UUID (UUID)
import Domain.Errors (AppError)
import Domain.Recipe (CreateRecipeInput (..), Recipe (..), UpdateRecipeInput (..), createRecipe, deleteRecipe, getAllRecipes, getRecipe, updateRecipe)
import Servant (NoContent (..))

getAllRecipesRoute :: AppM [Recipe]
getAllRecipesRoute = do
  pool <- asks dbPool
  liftIO $ getAllRecipes pool

getRecipeRoute :: UUID -> AppM Recipe
getRecipeRoute = withErrorHandling . getRecipeHandler

getRecipeHandler :: UUID -> AppM (Either AppError Recipe)
getRecipeHandler recipeId = do
  pool <- asks dbPool
  liftIO $ getRecipe pool recipeId

createRecipeRoute :: CreateRecipeInput -> AppM Recipe
createRecipeRoute = withErrorHandling . createRecipeHandler

createRecipeHandler :: CreateRecipeInput -> AppM (Either AppError Recipe)
createRecipeHandler input = do
  pool <- asks dbPool
  liftIO $ createRecipe pool input

updateRecipeRoute :: UUID -> UpdateRecipeInput -> AppM Recipe
updateRecipeRoute recipeId input = withErrorHandling $ updateRecipeHandler recipeId input

updateRecipeHandler :: UUID -> UpdateRecipeInput -> AppM (Either AppError Recipe)
updateRecipeHandler recipeId input = do
  pool <- asks dbPool
  liftIO $ updateRecipe pool recipeId input

deleteRecipeHandler :: UUID -> AppM NoContent
deleteRecipeHandler recipeId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent
