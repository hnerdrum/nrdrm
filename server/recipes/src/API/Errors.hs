module API.Errors
  ( handleError,
    withErrorHandling,
    AppError (..),
    DomainError (..),
    returnApiResult,
    mapApiResult,
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
    logMessage :: Text,
    namespace :: Namespace
  }

returnApiResult :: Either DomainError a -> Namespace -> Text -> AppM (Either AppError a)
returnApiResult result ns msg = return $ mapApiResult result ns msg

mapApiResult :: Either DomainError a -> Namespace -> Text -> Either AppError a
mapApiResult (Left err) ns msg = Left (AppError err msg ns)
mapApiResult (Right a) _ _ = Right a

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
  liftIO $ logError logEnv err.namespace err.logMessage
  throwError (fromDomainError err.error)

fromDomainError :: DomainError -> ServerError
fromDomainError (NotFoundError msg) = err404 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError (MultipleEntitiesError msg) = err409 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError (WrongPwdError msg) = err401 {errBody = encodeUtf8 (fromStrict msg)}
