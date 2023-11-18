{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    (
      startApp
    ) where

import API.Server
import App (AppContext(..))
import Control.Monad.Reader (liftIO)
import Database.Connection (createConnection)
import Data.Text (pack)
import qualified Data.ByteString.Char8 as B8
import Network.Wai.Handler.Warp
import Network.Wai.Middleware.Cors
import Network.Wai (Middleware)
import Servant
import Logger (initializeLogEnv, logInfo)
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
  let appName = "Recipes"
  logEnv <- initializeLogEnv
  let appContext = AppContext appName pool logEnv
  let port = Config.port config
  liftIO $ logInfo logEnv "startApp" $ "Starting " <> appName <> " app on port " <> (pack . show) port
  run port $ corsMiddleware (Config.allowedOrigins config) $ serve api $ server appContext
