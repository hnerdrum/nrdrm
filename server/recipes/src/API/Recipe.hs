module API.Recipe
  ( getAllRecipesRoute,
    getRecipeRoute,
    createRecipeRoute,
    updateRecipeRoute,
    deleteRecipeHandler,
  )
where

import API.Errors (withErrorHandling)
import App (AppM, runDbAction)
import Data.UUID (UUID)
import Domain.Errors (AppError)
import Domain.Recipe (CreateRecipeInput (..), Recipe (..), UpdateRecipeInput (..), createRecipe, deleteRecipe, getAllRecipes, getRecipe, updateRecipe)
import Servant (NoContent (..))

getAllRecipesRoute :: AppM [Recipe]
getAllRecipesRoute = runDbAction getAllRecipes

getRecipeRoute :: UUID -> AppM Recipe
getRecipeRoute = withErrorHandling . getRecipeHandler

getRecipeHandler :: UUID -> AppM (Either AppError Recipe)
getRecipeHandler recipeId = runDbAction (getRecipe recipeId)

createRecipeRoute :: CreateRecipeInput -> AppM Recipe
createRecipeRoute = withErrorHandling . createRecipeHandler

createRecipeHandler :: CreateRecipeInput -> AppM (Either AppError Recipe)
createRecipeHandler input = runDbAction (createRecipe input)

updateRecipeRoute :: UUID -> UpdateRecipeInput -> AppM Recipe
updateRecipeRoute recipeId input = withErrorHandling $ updateRecipeHandler recipeId input

updateRecipeHandler :: UUID -> UpdateRecipeInput -> AppM (Either AppError Recipe)
updateRecipeHandler recipeId input = runDbAction (updateRecipe recipeId input)

deleteRecipeHandler :: UUID -> AppM NoContent
deleteRecipeHandler recipeId = do
  runDbAction (deleteRecipe recipeId)
  return NoContent
