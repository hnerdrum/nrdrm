module API.Ingredient
  ( getAllIngredientsRoute,
    getIngredientRoute,
    createIngredientRoute,
    updateIngredientRoute,
    deleteIngredientRoute,
  )
where

import API.Errors (withErrorHandling)
import App (AppM, runDbAction)
import Data.UUID (UUID)
import Domain.Errors (AppError)
import Domain.Ingredient (CreateIngredientInput (..), Ingredient (..), UpdateIngredientInput (..), createIngredient, deleteIngredient, getAllIngredients, getIngredient, updateIngredient)
import Servant (NoContent (..))

getAllIngredientsRoute :: AppM [Ingredient]
getAllIngredientsRoute = runDbAction getAllIngredients

getIngredientRoute :: UUID -> AppM Ingredient
getIngredientRoute = withErrorHandling . getIngredientHandler

getIngredientHandler :: UUID -> AppM (Either AppError Ingredient)
getIngredientHandler ingredientId = runDbAction (getIngredient ingredientId)

createIngredientRoute :: CreateIngredientInput -> AppM Ingredient
createIngredientRoute = withErrorHandling . createIngredientHandler

createIngredientHandler :: CreateIngredientInput -> AppM (Either AppError Ingredient)
createIngredientHandler input = runDbAction (createIngredient input)

updateIngredientRoute :: UUID -> UpdateIngredientInput -> AppM Ingredient
updateIngredientRoute ingredientId input = withErrorHandling (updateIngredientHandler ingredientId input)

updateIngredientHandler :: UUID -> UpdateIngredientInput -> AppM (Either AppError Ingredient)
updateIngredientHandler ingredientId input = runDbAction (updateIngredient ingredientId input)

deleteIngredientRoute :: UUID -> AppM NoContent
deleteIngredientRoute ingredientId = do
  runDbAction (deleteIngredient ingredientId)
  return NoContent
