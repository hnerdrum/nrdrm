module API.Errors
  ( ToServantError,
    toServerError,
    handleError,
  )
where

import App (AppContext (..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Text (Text)
import Katip (Namespace)
import Logger (logError)
import Servant (ServerError, throwError)

class ToServantError a where
  toServerError :: a -> ServerError

handleError :: (ToServantError e) => Namespace -> Text -> e -> AppM a
handleError namespace message err = do
  logEnv <- asks appLogEnv
  liftIO $ logError logEnv namespace message
  throwError $ toServerError err
