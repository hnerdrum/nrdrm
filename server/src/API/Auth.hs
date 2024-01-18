{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE OverloadedRecordDot #-}

module API.Auth
(
  loginUserHandler
) where

import API.Errors (toServerError)
import API.Utils (resolveEitherAppResult)
import App (AppContext(..), AppM)
import Control.Monad.Reader (asks, liftIO)
import Data.Pool (Pool)
import qualified Database.PostgreSQL.Simple as PGSimple
import Data.Text
import Domain.Auth (LoginInput(..), loginUser, generateToken, upsertUserAuthToken)
import Domain.Errors (UserError(..))
import Domain.User (User(..))
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
