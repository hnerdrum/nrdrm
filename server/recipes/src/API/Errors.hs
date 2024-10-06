module API.Errors
  ( handleError,
    withErrorHandling,
    AppError (..),
    DomainError (..),
    returnApiResult,
    mapApiResult,
  )
where

import App (AppM)
import Control.Monad.Reader (liftIO)
import Data.Aeson (Value, object)
import Data.Text
import Data.Text.Lazy (fromStrict)
import Data.Text.Lazy.Encoding (encodeUtf8)
import Domain.Errors (DomainError (..))
import qualified Logger
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
    context :: Value
  }

returnApiResult :: Either DomainError a -> Text -> AppM (Either AppError a)
returnApiResult result msg = return $ mapApiResult result msg

mapApiResult :: Either DomainError a -> Text -> Either AppError a
mapApiResult (Left err) msg = Left (AppError err msg (object []))
mapApiResult (Right a) _ = Right a

handleError :: Text -> DomainError -> AppM a
handleError msg err = do
  liftIO $ Logger.error msg (object [])
  throwError $ fromDomainError err

withErrorHandling :: AppM (Either AppError b) -> AppM b
withErrorHandling = (either handleAppError return =<<)

handleAppError :: AppError -> AppM a
handleAppError err = do
  liftIO $ Logger.error err.message (object [])
  throwError (fromDomainError err.error)

fromDomainError :: DomainError -> ServerError
fromDomainError (NotFoundError msg) = err404 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError (MultipleEntitiesError msg) = err409 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError (WrongPwdError msg) = err401 {errBody = encodeUtf8 (fromStrict msg)}
