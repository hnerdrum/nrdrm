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
import Database.Migrations (runDbMigrations)
import qualified Logger
import Network.Wai.Handler.Warp (run)
import ORM.Db (connect)
import Servant (serve)

startApp :: IO ()
startApp = do
  config <- Config.loadConfig

  runDbMigrations $ Config.databaseUrl config

  let appName = "Recipes"
  pool <- connect $ Config.databaseUrl config

  let appContext =
        AppContext
          { name = appName,
            dbPool = pool,
            bootTime = Config.bootTime config,
            apiVersion = Config.apiVersion config
          }

  let port = Config.port config

  liftIO $ Logger.info ("Starting " <> appName <> " app on port " <> (pack . show) port) (object [])

  run port $ Logger.loggingMiddleware $ serve api $ server appContext
