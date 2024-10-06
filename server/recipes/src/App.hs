module App
  ( AppContext (..),
    AppM,
  )
where

import Control.Monad.Reader (ReaderT)
import Data.Pool (Pool)
import Data.Text (Text)
import Database.PostgreSQL.Simple (Connection)
import Servant (Handler)

data AppContext = AppContext
  { name :: Text,
    dbPool :: Pool Connection
  }

type AppM = ReaderT AppContext Handler
