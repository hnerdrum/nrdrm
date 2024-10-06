module API.Recipe
  ( getAllRecipesRoute,
    getRecipeRoute,
    createRecipeRoute,
    updateRecipeRoute,
    deleteRecipeHandler,
  )
where

import API.Auth (authMiddleware)
import API.Errors (withErrorHandling)
import App (AppContext (..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Aeson (object, (.=))
import Data.Text
import Data.UUID (UUID)
import Database.Recipe (CreateRecipeInput (..), UpdateRecipeInput (..))
import Domain.Errors (AppError, addErrorContext)
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
  return $ addErrorContext (object ["recipeId" .= recipeId]) result

createRecipeRoute :: CreateRecipeInput -> AppM Recipe
createRecipeRoute = withErrorHandling . createRecipeHandler

createRecipeHandler :: CreateRecipeInput -> AppM (Either AppError Recipe)
createRecipeHandler createRecipeInput = do
  pool <- asks dbPool
  liftIO $ createRecipe pool createRecipeInput

updateRecipeRoute :: UUID -> UpdateRecipeInput -> Maybe Text -> AppM Recipe
updateRecipeRoute recipeId input cookie = withErrorHandling (updateRecipeHandler recipeId input cookie)

updateRecipeHandler :: UUID -> UpdateRecipeInput -> Maybe Text -> AppM (Either AppError Recipe)
updateRecipeHandler = authMiddleware . updateRecipeUnsafe

updateRecipeUnsafe :: UUID -> UpdateRecipeInput -> AppM (Either AppError Recipe)
updateRecipeUnsafe recipeId updateRecipeInput = do
  pool <- asks dbPool
  result <- liftIO $ updateRecipe pool recipeId updateRecipeInput
  return $ addErrorContext (object ["recipeId" .= recipeId]) result

deleteRecipeHandler :: UUID -> Maybe Text -> AppM NoContent
deleteRecipeHandler = authMiddleware deleteRecipeUnsafe

deleteRecipeUnsafe :: UUID -> AppM NoContent
deleteRecipeUnsafe recipeId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteRecipe pool recipeId
  return NoContent
