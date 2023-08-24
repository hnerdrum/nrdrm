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

import API.Recipe (RecipeAPI, recipes)
import App (AppContext, AppM)
import Control.Monad.Reader (runReaderT)
import Data.Pool (Pool)
import Database.PostgreSQL.Simple (Connection)
import Servant

type API = RecipeAPI

server :: AppContext ->  Server API
server appContext = hoistServer api (runAppM appContext) apiHandlers

api :: Proxy API
api = Proxy

runAppM :: AppContext -> AppM a -> Handler a
runAppM appContext appAction = runReaderT appAction appContext

apiHandlers :: ServerT API AppM
apiHandlers = recipes
