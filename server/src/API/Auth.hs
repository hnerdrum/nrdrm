{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE OverloadedRecordDot #-}

module API.Auth
  (
    loginUserHandler
  , authMiddleware
  ) where

import API.Errors (toServerError)
import API.Utils (resolveEitherAppResult, liftMaybe)
import App (AppContext(..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Pool (Pool)
import qualified Database.PostgreSQL.Simple as PGSimple
import Data.Text
import Domain.Auth (LoginInput(..), loginUser, generateToken, upsertUserAuthToken, getAuthToken)
import Domain.Errors (UserError(..))
import Domain.User (User(..))
import Http.Cookies (getCookie)
import Http.Headers (SetCookieHeader)
import Katip (LogEnv, Namespace)
import Logger (logInfo, logError)
import Servant

authCookie :: Text -> Text
authCookie value = authCookieName <> "=" <> value <> "; Max-Age=" <> ((pack . show) authCookieMaxAge) <> "; Path=/; HttpOnly"

authCookieName :: Text
authCookieName = "recipes-login"

authCookieMaxAge :: Int
authCookieMaxAge = 86400 -- 24 hours

loginUserHandler :: LoginInput -> AppM (SetCookieHeader User)
loginUserHandler loginInput = do
  pool <- asks dbPool
  logEnv <- asks appLogEnv
  liftIO $ logInfo logEnv "loginUserHandler" "[POST] /api/v1/login/"
  eitherUser <- liftIO $ loginUser pool loginInput
  resolveEitherAppResult (handleError logEnv "loginUserHandler" "Error when trying to login with email") (handleValidUser pool) eitherUser

handleValidUser :: Pool PGSimple.Connection -> User -> AppM (SetCookieHeader User)
handleValidUser pool user = do
  token <- liftIO $ generateToken user
  _ <- liftIO $ upsertUserAuthToken pool user token
  let cookieHeader = addHeader $ authCookie token
  return $ cookieHeader $ user

handleError :: LogEnv -> Namespace -> Text -> UserError -> AppM (SetCookieHeader User)
handleError logEnv namespace message err = do
          liftIO $ logError logEnv namespace message
          throwError $ toServerError err

authMiddleware :: (a -> AppM b) -> a -> Maybe Text -> AppM b
authMiddleware action input maybeCookies = do
  pool <- asks dbPool
  maybeAuthCookie <- validateAuthCookie pool maybeCookies
  case maybeAuthCookie of
    Just _ -> action input
    _ -> throwError err403 { errBody = "Unauthorized" }

validateAuthCookie :: Pool PGSimple.Connection -> Maybe Text -> AppM (Maybe Text)
validateAuthCookie pool maybeCookies = do
  cookie <- liftMaybe $ getCookie authCookieName maybeCookies
  eitherAuthToken <- liftIO $ getAuthToken pool cookie
  case eitherAuthToken of
    Right _ -> return (Just cookie)
    Left _  -> return Nothing
