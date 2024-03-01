{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    (
      startApp
    ) where

import API.Server
import App (AppContext(..))
import qualified Config
import Control.Monad.Reader (liftIO)
import Database.Connection (createConnection)
import Database.Migrations (runDbMigrations)
import Data.Text (pack)
import qualified Data.ByteString.Char8 as B8
import Katip
import Logger (initializeLogEnv, logInfo)
import Network.Wai.Handler.Warp
import Network.Wai.Middleware.Cors
import Network.Wai (Middleware, rawPathInfo, requestMethod)
import Servant

corsResourcePolicy :: [String] -> CorsResourcePolicy
corsResourcePolicy allowedOrigins = simpleCorsResourcePolicy
   { corsRequestHeaders = ["Content-Type", "Credentials"]
   , corsMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
   , corsOrigins = Just (map B8.pack allowedOrigins, True)
   }

corsMiddleware :: [String] -> Middleware
corsMiddleware allowedOrigins = cors (const $ Just (corsResourcePolicy allowedOrigins))

loggingMiddleware :: LogEnv -> Middleware
loggingMiddleware logEnv app req res = do
  let method = requestMethod req
  logInfo logEnv "api" $ (pack . show) method <> " " <> (pack . show) (rawPathInfo req)
  app req $ res

startApp :: IO ()
startApp = do
  config <- Config.loadConfig
  pool <- createConnection $ Config.databaseUrl config
  runDbMigrations $ Config.databaseUrl config
  let appName = "Recipes"
  logEnv <- initializeLogEnv
  let appContext = AppContext appName pool logEnv
  let port = Config.port config
  liftIO $ logInfo logEnv "startApp" $ "Starting " <> appName <> " app on port " <> (pack . show) port
  run port $ corsMiddleware (Config.allowedOrigins config) $ (loggingMiddleware logEnv) $ serve api $ server appContext
