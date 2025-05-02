module API.Ingredient
  ( getAllIngredientsRoute,
    getIngredientRoute,
    createIngredientRoute,
    updateIngredientRoute,
    deleteIngredientRoute,
  )
where

import API.Errors (withErrorHandling)
import App (AppContext (..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.UUID (UUID)
import Database.Ingredient (CreateIngredientInput (..), UpdateIngredientInput (..))
import Domain.Errors (AppError)
import Domain.Ingredient (Ingredient (..), createIngredient, deleteIngredient, getAllIngredients, getIngredient, updateIngredient)
import Servant (NoContent (..))

getAllIngredientsRoute :: AppM [Ingredient]
getAllIngredientsRoute = do
  pool <- asks dbPool
  liftIO $ getAllIngredients pool

getIngredientRoute :: UUID -> AppM Ingredient
getIngredientRoute = withErrorHandling . getIngredientHandler

getIngredientHandler :: UUID -> AppM (Either AppError Ingredient)
getIngredientHandler ingredientId = do
  pool <- asks dbPool
  liftIO $ getIngredient pool ingredientId

createIngredientRoute :: CreateIngredientInput -> AppM Ingredient
createIngredientRoute = withErrorHandling . createIngredientHandler

createIngredientHandler :: CreateIngredientInput -> AppM (Either AppError Ingredient)
createIngredientHandler createIngredientInput = do
  pool <- asks dbPool
  liftIO $ createIngredient pool createIngredientInput

updateIngredientRoute :: UUID -> UpdateIngredientInput -> AppM Ingredient
updateIngredientRoute ingredientId input = withErrorHandling (updateIngredientHandler ingredientId input)

updateIngredientHandler :: UUID -> UpdateIngredientInput -> AppM (Either AppError Ingredient)
updateIngredientHandler ingredientId updateIngredientInput = do
  pool <- asks dbPool
  liftIO $ updateIngredient pool ingredientId updateIngredientInput

deleteIngredientRoute :: UUID -> AppM NoContent
deleteIngredientRoute ingredientId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteIngredient pool ingredientId
  return NoContent
