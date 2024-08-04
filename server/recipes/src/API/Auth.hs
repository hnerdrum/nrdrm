module API.Auth
  (
    meHandler
  , loginUserHandler
  , authMiddleware
  ) where

import API.Errors (handleError)
import API.Utils (resolveEitherAppResult, eitherToMaybe)
import App (AppContext(..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Pool (Pool)
import qualified Database.PostgreSQL.Simple as PGSimple
import Data.Text ( Text )
import Domain.Auth (LoginInput(..), UserSettings(..), Auth(..), loginUser, generateToken, upsertUserAuthToken, getAuthToken)
import Domain.User (User(..))
import Http.Cookies (getCookie, authCookie, authCookieName)
import Http.Headers (SetCookieHeader)
import Servant
    ( addHeader, err401, throwError, ServerError(errBody) )

meHandler :: Maybe Text -> AppM UserSettings
meHandler maybeCookies = do
  pool <- asks dbPool
  maybeAuth <- validateAuth pool maybeCookies
  return $ UserSettings { auth = maybeAuth }

loginUserHandler :: LoginInput -> AppM (SetCookieHeader User)
loginUserHandler loginInput = do
  pool <- asks dbPool
  eitherUser <- liftIO $ loginUser pool loginInput
  resolveEitherAppResult (handleError "loginUserHandler" "Error when trying to login with email") (handleValidUser pool) eitherUser

handleValidUser :: Pool PGSimple.Connection -> User -> AppM (SetCookieHeader User)
handleValidUser pool user = do
  token <- liftIO $ generateToken user
  _ <- liftIO $ upsertUserAuthToken pool user token
  let cookieHeader = addHeader $ authCookie token
  return $ cookieHeader $ user

authMiddleware :: (a -> AppM b) -> a -> Maybe Text -> AppM b
authMiddleware action input maybeCookies = do
  pool <- asks dbPool
  maybeAuth <- validateAuth pool maybeCookies
  maybe (throwError err401 { errBody = "Unauthorized" }) (const $ action input) maybeAuth

validateAuth :: Pool PGSimple.Connection -> Maybe Text -> AppM (Maybe Auth)
validateAuth pool maybeCookies = do
  maybeCookie <- getCookie authCookieName <$> return maybeCookies
  maybe (return Nothing) (getAuthFromCookie pool) maybeCookie

getAuthFromCookie :: Pool PGSimple.Connection -> Text -> AppM (Maybe Auth)
getAuthFromCookie pool cookie = do
  eitherAuth <- liftIO $ getAuthToken pool cookie
  return $ eitherToMaybe eitherAuth
