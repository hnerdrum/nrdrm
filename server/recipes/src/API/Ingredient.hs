module API.Ingredient
  ( getAllIngredientsHandler
  , getIngredientHandler
  , createIngredientHandler
  , updateIngredientHandler
  , deleteIngredientHandler
  ) where

import API.Errors (handleError)
import API.Utils (resolveEitherAppResult)
import App (AppContext(..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Text ( pack )
import Data.UUID ( UUID )
import Database.Ingredient (CreateIngredientInput(..), UpdateIngredientInput(..))
import Domain.Ingredient (Ingredient(..), getAllIngredients, getIngredient, createIngredient, updateIngredient, deleteIngredient)
import Servant ( NoContent(..) )

getAllIngredientsHandler :: AppM [Ingredient]
getAllIngredientsHandler = do
  pool <- asks dbPool
  liftIO $ getAllIngredients pool

getIngredientHandler :: UUID -> AppM Ingredient
getIngredientHandler ingredientId = do
  pool <- asks dbPool
  eitherIngredient <- liftIO $ getIngredient pool ingredientId
  resolveEitherAppResult (handleError "getIngredientHandler" ("Ingredient with ID: " <> (pack . show) ingredientId <> " not found")) return eitherIngredient

createIngredientHandler :: CreateIngredientInput -> AppM Ingredient
createIngredientHandler createIngredientInput = do
  pool <- asks dbPool
  eitherIngredient <- liftIO $ createIngredient pool createIngredientInput
  resolveEitherAppResult (handleError "createIngredientHandler" "Ingredient not found") return eitherIngredient

updateIngredientHandler :: UUID -> UpdateIngredientInput -> AppM Ingredient
updateIngredientHandler ingredientId updateIngredientInput = do
  pool <- asks dbPool
  eitherIngredient <- liftIO $ updateIngredient pool ingredientId updateIngredientInput
  resolveEitherAppResult (handleError "updateIngredientHandler" ("Ingredient with ID: " <> (pack . show) ingredientId <> " not found")) return eitherIngredient

deleteIngredientHandler :: UUID -> AppM NoContent
deleteIngredientHandler ingredientId = do
  pool <- asks dbPool
  _ <- liftIO $ deleteIngredient pool ingredientId
  return NoContent
