
module App
    (
      AppContext(..)
      , AppM
    ) where

import Control.Monad.Reader (ReaderT)
import Data.Pool (Pool)
import Database.PostgreSQL.Simple (Connection)
import Servant

newtype AppContext = AppContext { dbPool :: Pool Connection }

type AppM = ReaderT AppContext Handler
