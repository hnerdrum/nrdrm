
module App
    (
      AppContext(..)
      , AppM
    ) where

import Control.Monad.Reader (ReaderT)
import Data.Pool (Pool)
import Database.PostgreSQL.Simple (Connection)
import Katip
import Servant

data AppContext = AppContext
  { dbPool :: Pool Connection
  , appLogEnv :: LogEnv
  }

type AppM = ReaderT AppContext Handler
