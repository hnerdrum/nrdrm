{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}

module Lib
    (
      startApp
    ) where

import API.Server
import App (AppContext(..))
import Database.Connection (createConnection)
import Network.Wai.Handler.Warp
import Servant

startApp :: IO ()
startApp = do
  pool <- createConnection
  let appContext = AppContext pool
  run 8000 $ serve api $ server appContext
