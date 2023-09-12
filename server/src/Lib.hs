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
import Logger (initializeLogEnv)

startApp :: IO ()
startApp = do
  pool <- createConnection
  logEnv <- initializeLogEnv
  let appContext = AppContext pool logEnv
  run 8000 $ serve api $ server appContext
