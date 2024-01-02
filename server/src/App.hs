
module App
    (
      AppContext(..)
      , AppM
    ) where

import Control.Monad.Reader (ReaderT)
import Data.Pool (Pool)
import Data.Text
import Database.PostgreSQL.Simple (Connection)
import Katip
import Servant

data AppContext = AppContext
  { name :: Text
  , dbPool :: Pool Connection
  , appLogEnv :: LogEnv
  }

type AppM = ReaderT AppContext Handler
