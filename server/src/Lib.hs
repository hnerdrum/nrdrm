module Lib
    ( startApp
    ) where

import API.App (app)
import Database.Connection (createConnection)
import Network.Wai.Handler.Warp

startApp :: IO ()
startApp = do
  _ <- createConnection
  run 8000 app
