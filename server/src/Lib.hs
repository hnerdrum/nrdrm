
module Lib
    ( startApp
    ) where

import API.App
import Database.Connection (createConnection)
import Network.Wai.Handler.Warp

startApp :: IO ()
startApp = do
  pool <- createConnection
  let appContext = AppContext pool
  run 8000 $ app appContext
