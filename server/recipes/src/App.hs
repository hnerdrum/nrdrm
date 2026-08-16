module App
  ( AppContext (..),
    AppM,
  )
where

import Control.Monad.Reader (ReaderT)
import Data.Text (Text)
import ORM.Db (DbPool)
import Servant (Handler)

data AppContext = AppContext
  { name :: Text,
    dbPool :: DbPool,
    bootTime :: Text,
    apiVersion :: Text
  }

type AppM = ReaderT AppContext Handler
