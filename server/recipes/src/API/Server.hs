module API.Server
  ( server,
    api,
  )
where

import API.Health (healthHandler)
import API.Ingredient (createIngredientRoute, deleteIngredientRoute, getAllIngredientsRoute, getIngredientRoute, updateIngredientRoute)
import API.Recipe (createRecipeRoute, deleteRecipeHandler, getAllRecipesRoute, getRecipeRoute, updateRecipeRoute)
import App (AppContext, AppM)
import Control.Monad.Reader (runReaderT)
import Data.UUID (UUID)
import Database.Ingredient (CreateIngredientInput (..), UpdateIngredientInput (..))
import Database.Recipe (CreateRecipeInput (..), UpdateRecipeInput (..))
import Domain.Health (HealthCheck (..))
import Domain.Ingredient (Ingredient (..))
import Domain.Recipe (Recipe (..))
import Servant
  ( Capture,
    DeleteNoContent,
    Get,
    Handler,
    HasServer (ServerT),
    JSON,
    PostCreated,
    Proxy (..),
    Put,
    ReqBody,
    Server,
    hoistServer,
    type (:<|>) (..),
    type (:>),
  )

type API =
  "api"
    :> "v1"
    :> ( Get '[JSON] [Recipe]
           :<|> Capture "recipeId" UUID :> Get '[JSON] Recipe
           :<|> ReqBody '[JSON] CreateRecipeInput :> PostCreated '[JSON] Recipe
           :<|> Capture "recipeId" UUID :> ReqBody '[JSON] UpdateRecipeInput :> Put '[JSON] Recipe
           :<|> Capture "recipeId" UUID :> DeleteNoContent
           :<|> "ingredients" :> Get '[JSON] [Ingredient]
           :<|> "ingredients" :> Capture "ingredientId" UUID :> Get '[JSON] Ingredient
           :<|> "ingredients" :> ReqBody '[JSON] CreateIngredientInput :> PostCreated '[JSON] Ingredient
           :<|> "ingredients" :> Capture "ingredientId" UUID :> ReqBody '[JSON] UpdateIngredientInput :> Put '[JSON] Ingredient
           :<|> "ingredients" :> Capture "ingredientId" UUID :> DeleteNoContent
           :<|> "health" :> Get '[JSON] HealthCheck
       )

server :: AppContext -> Server API
server appContext = hoistServer api (runAppM appContext) apiHandlers

api :: Proxy API
api = Proxy

runAppM :: AppContext -> AppM a -> Handler a
runAppM appContext appAction = runReaderT appAction appContext

apiHandlers :: ServerT API AppM
apiHandlers =
  getAllRecipesRoute
    :<|> getRecipeRoute
    :<|> createRecipeRoute
    :<|> updateRecipeRoute
    :<|> deleteRecipeHandler
    :<|> getAllIngredientsRoute
    :<|> getIngredientRoute
    :<|> createIngredientRoute
    :<|> updateIngredientRoute
    :<|> deleteIngredientRoute
    :<|> healthHandler
