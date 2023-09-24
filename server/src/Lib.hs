{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    (
      startApp
    ) where

import API.Server
import App (AppContext(..))
import Database.Connection (createConnection)
import Network.Wai.Handler.Warp
import Network.Wai.Middleware.Cors
import Network.Wai (Middleware)
import Servant
import Logger (initializeLogEnv)

corsResourcePolicy :: CorsResourcePolicy
corsResourcePolicy = simpleCorsResourcePolicy
   { corsRequestHeaders = ["Content-Type"]
   , corsMethods = ["GET", "POST", "PUT", "DELETE"]
   , corsOrigins = Just (["http://localhost:3000"], True)
   }

corsMiddleware :: Middleware
corsMiddleware = cors (const $ Just corsResourcePolicy)

startApp :: IO ()
startApp = do
  pool <- createConnection
  logEnv <- initializeLogEnv
  let appContext = AppContext pool logEnv
  run 8000 $ corsMiddleware $ serve api $ server appContext
