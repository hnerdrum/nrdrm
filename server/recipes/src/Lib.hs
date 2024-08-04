module Lib
  ( startApp,
  )
where

import API.Server (api, server)
import App (AppContext (..))
import qualified Config
import Control.Monad.Reader (liftIO)
import Data.Text (pack)
import Database.Connection (createConnection)
import Database.Migrations (runDbMigrations)
import Http.Cors (corsMiddleware)
import Logger (initializeLogEnv, logInfo, loggingMiddleware)
import Network.Wai.Handler.Warp (run)
import Servant (serve)

startApp :: IO ()
startApp = do
  config <- Config.loadConfig

  runDbMigrations $ Config.databaseUrl config

  let appName = "Recipes"
  pool <- createConnection $ Config.databaseUrl config
  logEnv <- initializeLogEnv
  let appContext = AppContext appName pool logEnv

  let port = Config.port config

  liftIO $ logInfo logEnv "app" $ "Starting " <> appName <> " app on port " <> (pack . show) port

  run port $ corsMiddleware (Config.allowedOrigins config) $ loggingMiddleware logEnv $ serve api $ server appContext
