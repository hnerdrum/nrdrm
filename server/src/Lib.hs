{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    ( startApp
    , app
    ) where

import Data.Aeson
import Data.Aeson.TH
import Database.PostgreSQL.Simple
import Network.Wai
import Network.Wai.Handler.Warp
import Servant

data User = User
  { id        :: Int
  , firstName  :: String
  , lastName  :: String
  } deriving (Eq, Show)

$(deriveJSON defaultOptions ''User)

type API = "users" :> Get '[JSON] [User]

localPG :: ConnectInfo
localPG = defaultConnectInfo
        { connectHost = "localhost"
        , connectDatabase = "nrdrm"
        , connectUser = "nrdrm"
        , connectPassword = "nrdrm"
        }

startApp :: IO ()
startApp = do
  conn <- connect localPG
  mapM_ print =<< (query_ conn "SELECT 1 + 1" :: IO [Only Int])
  run 8000 app

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
