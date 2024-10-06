module API.Recipe
  ( getAllRecipesRoute,
    getRecipeRoute,
    createRecipeRoute,
    updateRecipeRoute,
    deleteRecipeHandler,
  )
where

import API.Auth (authMiddleware)
import API.Errors (AppError, returnApiResult, withErrorHandling)
import App (AppContext (..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Text (Text, pack)
import Data.UUID (UUID)
import Database.Recipe (CreateRecipeInput (..), UpdateRecipeInput (..))
import Domain.Recipe (Recipe (..), createRecipe, deleteRecipe, getAllRecipes, getRecipe, updateRecipe)
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
  result <- liftIO $ getRecipe pool recipeId
  returnApiResult result ("Failed to get recipe with ID: " <> (pack . show) recipeId)

createRecipeRoute :: CreateRecipeInput -> AppM Recipe
createRecipeRoute = withErrorHandling . createRecipeHandler

createRecipeHandler :: CreateRecipeInput -> AppM (Either AppError Recipe)
createRecipeHandler createRecipeInput = do
  pool <- asks dbPool
  result <- liftIO $ createRecipe pool createRecipeInput
  returnApiResult result "Failed to create recipe"

updateRecipeRoute :: UUID -> UpdateRecipeInput -> Maybe Text -> AppM Recipe
updateRecipeRoute recipeId input cookie = withErrorHandling (updateRecipeHandler recipeId input cookie)

updateRecipeHandler :: UUID -> UpdateRecipeInput -> Maybe Text -> AppM (Either AppError Recipe)
updateRecipeHandler = authMiddleware . updateRecipeUnsafe

updateRecipeUnsafe :: UUID -> UpdateRecipeInput -> AppM (Either AppError Recipe)
updateRecipeUnsafe recipeId updateRecipeInput = do
  pool <- asks dbPool
  result <- liftIO $ updateRecipe pool recipeId updateRecipeInput
  returnApiResult result ("Failed to update recipe with ID: " <> (pack . show) recipeId)

deleteRecipeHandler :: UUID -> Maybe Text -> AppM NoContent
deleteRecipeHandler = authMiddleware deleteRecipeUnsafe

deleteRecipeUnsafe :: UUID -> AppM NoContent
deleteRecipeUnsafe recipeId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent
