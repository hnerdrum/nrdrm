{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE TypeFamilies #-}

module API.Server
    (
     server
     , api
    ) where

import API.Auth (meHandler, loginUserHandler)
import API.Health (healthHandler)
import API.Ingredient (getAllIngredientsHandler, getIngredientHandler, createIngredientHandler, updateIngredientHandler, deleteIngredientHandler)
import API.Recipe (getAllRecipesHandler, getRecipeHandler, createRecipeHandler, updateRecipeHandler, deleteRecipeHandler)
import App (AppContext, AppM)
import Control.Monad.Reader (runReaderT)
import Data.Text
import Data.UUID
import Database.Recipe (CreateRecipeInput(..), UpdateRecipeInput(..))
import Database.Ingredient (CreateIngredientInput(..), UpdateIngredientInput(..))
import Domain.Auth (LoginInput(..), UserSettings(..))
import Domain.Ingredient (Ingredient(..))
import Domain.Recipe (Recipe(..))
import Domain.User (User(..))
import Http.Headers (SetCookieHeader, CookieHeader)
import Servant

type API =
  "api" :> "v1" :> (
       Get '[JSON] [Recipe]
  :<|> Capture "recipeId" UUID :> Get '[JSON] Recipe
  :<|> ReqBody '[JSON] CreateRecipeInput :> PostCreated '[JSON] Recipe
  :<|> Capture "recipeId" UUID :> ReqBody '[JSON] UpdateRecipeInput :> Header CookieHeader Text :> Put '[JSON] Recipe
  :<|> Capture "recipeId" UUID :> Header CookieHeader Text :> DeleteNoContent

  :<|> "ingredients" :> Get '[JSON] [Ingredient]
  :<|> "ingredients" :> Capture "ingredientId" UUID :> Get '[JSON] Ingredient
  :<|> "ingredients" :> ReqBody '[JSON] CreateIngredientInput :> PostCreated '[JSON] Ingredient
  :<|> "ingredients" :> Capture "ingredientId" UUID :> ReqBody '[JSON] UpdateIngredientInput :> Put '[JSON] Ingredient
  :<|> "ingredients" :> Capture "ingredientId" UUID :> DeleteNoContent

  :<|> "me" :> Header CookieHeader Text :> Get '[JSON] UserSettings
  :<|> "login" :> ReqBody '[JSON] LoginInput :> Post '[JSON] (SetCookieHeader User)

  :<|> "health" :> Get '[PlainText] Text
  )

server :: AppContext -> Server API
server appContext = hoistServer api (runAppM appContext) apiHandlers

api :: Proxy API
api = Proxy

runAppM :: AppContext -> AppM a -> Handler a
runAppM appContext appAction = runReaderT appAction appContext

apiHandlers :: ServerT API AppM
apiHandlers =
         getAllRecipesHandler
    :<|> getRecipeHandler
    :<|> createRecipeHandler
    :<|> updateRecipeHandler
    :<|> deleteRecipeHandler

    :<|> getAllIngredientsHandler
    :<|> getIngredientHandler
    :<|> createIngredientHandler
    :<|> updateIngredientHandler
    :<|> deleteIngredientHandler

    :<|> meHandler
    :<|> loginUserHandler

    :<|> healthHandler
