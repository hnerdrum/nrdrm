module API.Errors
  ( handleAppError,
    withErrorHandling,
    DomainError (..),
  )
where

import App (AppM)
import Control.Monad.Reader (liftIO)
import Data.Text
import Data.Text.Lazy (fromStrict)
import Data.Text.Lazy.Encoding (encodeUtf8)
import Domain.Errors (AppError (..), DomainError (..))
import qualified Logger
import Servant
  ( ServerError (errBody),
    err401,
    err404,
    err409,
    err500,
    throwError,
  )

withErrorHandling :: AppM (Either AppError b) -> AppM b
withErrorHandling = (either handleAppError return =<<)

handleAppError :: AppError -> AppM a
handleAppError err = do
  liftIO $ Logger.error err.message err.context
  throwError (fromAppError err)

fromAppError :: AppError -> ServerError
fromAppError err = fromDomainError err.error err.message

fromDomainError :: DomainError -> Text -> ServerError
fromDomainError NotFoundError msg = err404 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError MultipleEntitiesError msg = err409 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError ConflictError msg = err409 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError InternalError msg = err500 {errBody = encodeUtf8 (fromStrict msg)}
fromDomainError WrongPwdError msg = err401 {errBody = encodeUtf8 (fromStrict msg)}
