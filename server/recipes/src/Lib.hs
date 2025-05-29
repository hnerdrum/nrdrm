module Lib
  ( startApp,
  )
where

import API.Server (api, server)
import App (AppContext (..))
import qualified Config
import Control.Monad.Reader (liftIO)
import Data.Aeson (object)
import Data.Text (pack)
import Database.Connection (createConnection)
import Database.Migrations (runDbMigrations)
import qualified Logger
import Network.Wai.Handler.Warp (run)
import Servant (serve)

startApp :: IO ()
startApp = do
  config <- Config.loadConfig

  runDbMigrations $ Config.databaseUrl config

  let appName = "Recipes"
  pool <- createConnection $ Config.databaseUrl config

  let appContext = AppContext appName pool

  let port = Config.port config

  liftIO $ Logger.info ("Starting " <> appName <> " app on port " <> (pack . show) port) (object [])

  run port $ Logger.loggingMiddleware $ serve api $ server appContext
