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
import Http.Cors (corsMiddleware)
import Logger (initializeLogEnv, loggingMiddleware, logInfo)
import Network.Wai.Handler.Warp
import Servant

startApp :: IO ()
startApp = do
  config <- Config.loadConfig
  pool <- createConnection $ Config.databaseUrl config
  runDbMigrations $ Config.databaseUrl config
  let appName = "Recipes"
  logEnv <- initializeLogEnv
  let appContext = AppContext appName pool logEnv
  let port = Config.port config
  liftIO $ logInfo logEnv "app" $ "Starting " <> appName <> " app on port " <> (pack . show) port
  run port $ corsMiddleware (Config.allowedOrigins config) $ (loggingMiddleware logEnv) $ serve api $ server appContext
