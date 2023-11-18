{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    (
      startApp
    ) where

import API.Server
import App (AppContext(..))
import Database.Connection (createConnection)
import qualified Data.ByteString.Char8 as B8
import Network.Wai.Handler.Warp
import Network.Wai.Middleware.Cors
import Network.Wai (Middleware)
import Servant
import Logger (initializeLogEnv)
import qualified Config

corsResourcePolicy :: [String] -> CorsResourcePolicy
corsResourcePolicy allowedOrigins = simpleCorsResourcePolicy
   { corsRequestHeaders = ["Content-Type"]
   , corsMethods = ["GET", "POST", "PUT", "DELETE"]
   , corsOrigins = Just (map B8.pack allowedOrigins, True)
   }

corsMiddleware :: [String] -> Middleware
corsMiddleware allowedOrigins = cors (const $ Just (corsResourcePolicy allowedOrigins))

startApp :: IO ()
startApp = do
  config <- Config.loadConfig
  pool <- createConnection $ Config.databaseUrl config
  logEnv <- initializeLogEnv
  let appContext = AppContext pool logEnv
  run 8000 $ corsMiddleware (Config.allowedOrigins config) $ serve api $ server appContext
