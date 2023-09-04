{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}

module API.Server
    (
     server
     , api
    ) where

import API.Ingredient (getAllIngredientsHandler)
import API.Recipe (getAllRecipesHandler, getRecipeHandler, createRecipeHandler, updateRecipeHandler, deleteRecipeHandler)
import App (AppContext, AppM)
import Control.Monad.Reader (runReaderT)
import Data.UUID
import Database.Recipe (CreateRecipeInput(..), UpdateRecipeInput(..))
import Database.Ingredient (Ingredient(..))
import Domain.Recipe (Recipe(..))
import Servant

type API =
  "api" :> "v1" :> (
       "recipes" :> Get '[JSON] [Recipe]
  :<|> "recipes" :> Capture "recipeId" UUID :> Get '[JSON] Recipe
  :<|> "recipes" :> ReqBody '[JSON] CreateRecipeInput :> PostCreated '[JSON] Recipe
  :<|> "recipes" :> Capture "recipeId" UUID :> ReqBody '[JSON] UpdateRecipeInput :> Put '[JSON] Recipe
  :<|> "recipes" :> Capture "recipeId" UUID :> DeleteNoContent

  :<|> "ingredients" :> Get '[JSON] [Ingredient]
  )

server :: AppContext ->  Server API
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
