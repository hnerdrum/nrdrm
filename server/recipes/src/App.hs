module App
  ( AppContext (..),
    AppM,
    runDbAction,
    runTxAction,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Reader (ReaderT, asks)
import Data.Text (Text)
import Poppy.Db (Db (..), DbPool, runDb, withTransaction)
import Servant (Handler)

data AppContext = AppContext
  { name :: Text,
    dbPool :: DbPool,
    bootTime :: Text,
    apiVersion :: Text
  }

type AppM = ReaderT AppContext Handler

runDbAction :: Db a -> AppM a
runDbAction action = do
  pool <- asks dbPool
  liftIO $ runDb pool action

runTxAction :: Db a -> AppM a
runTxAction action = do
  pool <- asks dbPool
  liftIO $ withTransaction pool action
