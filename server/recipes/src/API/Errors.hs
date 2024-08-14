module API.Errors
  ( ToServantError,
    toServerError,
    handleError,
    withErrorHandling,
    AppError (..),
    DomainError (..),
  )
where

import App (AppContext (..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Text
import Data.Text.Lazy (fromStrict)
import Data.Text.Lazy.Encoding (encodeUtf8)
import Domain.Errors (DomainError (..))
import Katip (Namespace)
import Logger (logError)
import Servant
  ( ServerError (errBody),
    err401,
    err404,
    err409,
    throwError,
  )

data AppError = AppError
  { error :: DomainError,
    message :: Text,
    namespace :: Namespace
  }

class ToServantError a where
  toServerError :: a -> ServerError

handleError :: Namespace -> Text -> DomainError -> AppM a
handleError ns msg err = do
  logEnv <- asks appLogEnv
  liftIO $ logError logEnv ns msg
  throwError $ fromDomainError err

withErrorHandling :: AppM (Either AppError b) -> AppM b
withErrorHandling = (either handleAppError return =<<)

handleAppError :: AppError -> AppM a
handleAppError err = do
  logEnv <- asks appLogEnv
  liftIO $ logError logEnv err.namespace err.message
  throwError (fromDomainError err.error)

fromDomainError :: DomainError -> ServerError
fromDomainError (NotFoundError msg) = err404 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError (MultipleEntitiesError msg) = err409 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError (WrongPwdError msg) = err401 {errBody = encodeUtf8 (fromStrict msg)}
