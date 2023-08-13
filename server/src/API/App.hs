{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TypeOperators   #-}

module API.App
    (
      app
    ) where

import Domain.Model (User(..))
import Network.Wai
import Network.Wai.Handler.Warp
import Servant

type API = "users" :> Get '[JSON] [User]

app :: Application
app = serve api server

api :: Proxy API
api = Proxy

server :: Server API
server = return users

users :: [User]
users = [ User 1 "Isaac" "Newton"
        , User 2 "Albert" "Einstein"
        ]
