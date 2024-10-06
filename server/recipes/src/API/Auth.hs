module API.Auth
  ( meHandler,
    loginUserHandler,
    authMiddleware,
  )
where

import API.Errors (handleAppError)
import API.Utils (eitherToMaybe, resolveEitherAppResult)
import App (AppContext (..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Pool (Pool)
import Data.Text (Text)
import qualified Database.PostgreSQL.Simple as PGSimple
import Domain.Auth (Auth (..), LoginInput (..), UserSettings (..), generateToken, getAuthToken, loginUser, upsertUserAuthToken)
import Domain.User (User (..))
import Http.Cookies (authCookie, authCookieName, getCookie)
import Http.Headers (SetCookieHeader)
import Servant
  ( ServerError (errBody),
    addHeader,
    err401,
    throwError,
  )

meHandler :: Maybe Text -> AppM UserSettings
meHandler maybeCookies = do
  pool <- asks dbPool
  maybeAuth <- validateAuth pool maybeCookies
  return $ UserSettings {auth = maybeAuth}

loginUserHandler :: LoginInput -> AppM (SetCookieHeader User)
loginUserHandler loginInput = do
  pool <- asks dbPool
  result <- liftIO $ loginUser pool loginInput
  resolveEitherAppResult handleAppError (handleValidUser pool) result

handleValidUser :: Pool PGSimple.Connection -> User -> AppM (SetCookieHeader User)
handleValidUser pool user = do
  token <- liftIO $ generateToken user
  _ <- liftIO $ upsertUserAuthToken pool user token
  let cookieHeader = addHeader $ authCookie token
  return $ cookieHeader user

authMiddleware :: (a -> AppM b) -> a -> Maybe Text -> AppM b
authMiddleware action input maybeCookies = do
  pool <- asks dbPool
  maybeAuth <- validateAuth pool maybeCookies
  maybe (throwError err401 {errBody = "Unauthorized"}) (const $ action input) maybeAuth

validateAuth :: Pool PGSimple.Connection -> Maybe Text -> AppM (Maybe Auth)
validateAuth pool maybeCookies = do
  let maybeCookie = getCookie authCookieName maybeCookies
  maybe (return Nothing) (getAuthFromCookie pool) maybeCookie

getAuthFromCookie :: Pool PGSimple.Connection -> Text -> AppM (Maybe Auth)
getAuthFromCookie pool cookie = do
  eitherAuth <- liftIO $ getAuthToken pool cookie
  return $ eitherToMaybe eitherAuth
