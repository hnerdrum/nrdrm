{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}

module API.App
    (
     app
     , AppContext(..)
    ) where

import Control.Monad.Reader (ReaderT, asks, runReaderT, liftIO)
import Data.Pool (Pool, withResource)
import Database.PostgreSQL.Simple
import Domain.Recipe
import Network.Wai
import Servant

newtype AppContext = AppContext { dbPool :: Pool Connection }

type AppM = ReaderT AppContext Handler

type API = "recipes" :> Get '[JSON] [Recipe]

app :: AppContext -> Application
app appContext = serve api $ server appContext

server :: AppContext ->  Server API
server appContext = hoistServer api (runAppM appContext) apiHandlers

api :: Proxy API
api = Proxy

runAppM :: AppContext -> AppM a -> Handler a
runAppM appContext appAction = runReaderT appAction appContext

apiHandlers :: ServerT API AppM
apiHandlers = recipes

recipes :: AppM [Recipe]
recipes = do
  pool <- asks dbPool
  dbRecipeIngredients <- liftIO $ withResource pool $ \conn -> query_ conn "SELECT r.id, r.created_at, r.updated_at, r.name, r.description, i.id, i.created_at , i.updated_at, i.name, ri.amount, ri.unit FROM recipe r JOIN recipe_ingredient ri ON r.id = ri.recipe_id JOIN ingredient i ON i.id = ri.ingredient_id"
  return $ fromDbRecipeIngredients dbRecipeIngredients
