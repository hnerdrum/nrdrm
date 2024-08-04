{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

{-# HLINT ignore "Use newtype instead of data" #-}

module Domain.Auth
  ( LoginInput (..),
    UserSettings (..),
    Auth (..),
    generateToken,
    loginUser,
    upsertUserAuthToken,
    getAuthToken,
  )
where

import Control.Monad.Reader (liftIO)
import Crypto.BCrypt (validatePassword)
import Crypto.Hash (Digest, SHA256, hash)
import Data.Aeson
import Data.Aeson.TH
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8 as BS
import Data.Pool (Pool, withResource)
import Data.Text
import qualified Data.Text.Encoding as TE
import Data.Time
import Data.UUID
import Database.Auth (AuthTokenStatus (..), DbAuthToken (..))
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.User (DbUser (..))
import Domain.Errors (AuthTokenError (..), UserError (..))
import Domain.User (User (..), fromDbUser, getUserByEmail)

type Token = Text

data Auth = Auth
  {userId :: UUID}
  deriving (Show)

$(deriveJSON defaultOptions ''Auth)

data UserSettings = UserSettings
  {auth :: Maybe Auth}
  deriving (Show)

$(deriveJSON defaultOptions ''UserSettings)

data LoginInput = LoginInput
  { email :: Text,
    password :: Text
  }
  deriving (Show)

instance FromJSON LoginInput where
  parseJSON = withObject "LoginInput" $ \obj -> do
    emailValue <- obj .: "email"
    passwordValue <- obj .: "password"
    return $
      LoginInput
        { email = emailValue,
          password = passwordValue
        }

loginUser :: Pool PGSimple.Connection -> LoginInput -> IO (Either UserError User)
loginUser pool loginInput = do
  eitherUser <- liftIO $ getUserByEmail pool loginInput.email
  return $ eitherUser >>= validateUserLogin loginInput

validateUserLogin :: LoginInput -> DbUser -> Either UserError User
validateUserLogin loginInput user = fromDbUser <$> validateUserPassword user loginInput.password

validateUserPassword :: DbUser -> Text -> Either UserError DbUser
validateUserPassword user inputPassword
  | validatePassword (TE.encodeUtf8 user.passwordHash) (TE.encodeUtf8 inputPassword) = Right user
  | otherwise = Left WrongPasswordError

upsertUserAuthToken :: Pool PGSimple.Connection -> User -> Token -> IO ()
upsertUserAuthToken pool user token =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      now <- getCurrentTime
      _ <-
        PGSimple.execute
          conn
          [sql|
           INSERT INTO auth_token (value, status, user_id)
           VALUES (?, ?, ?)
           ON CONFLICT (value, user_id)
           DO UPDATE SET status = EXCLUDED.status, updated_at = ?
         |]
          (token, NORMAL, user.id, now)
      return ()

getAuthToken :: Pool PGSimple.Connection -> Text -> IO (Either AuthTokenError Auth)
getAuthToken pool val =
  withResource pool $ \conn -> do
    authTokens <-
      PGSimple.query
        conn
        [sql|
        SELECT id, created_at, updated_at, val, user_id
        FROM auth_token
        WHERE val = ? AND status = ?
      |]
        (val, NORMAL)
    return $ mapAuthTokenResult authTokens

mapAuthTokenResult :: [DbAuthToken] -> Either AuthTokenError Auth
mapAuthTokenResult [] = Left AuthTokenNotFound
mapAuthTokenResult [token] = Right $ Auth {userId = token.userId}
mapAuthTokenResult _ = Left MultipleAuthTokensFound

generateToken :: User -> IO Token
generateToken user = do
  let input = BS.concat [userIdBytes, emailBytes]
      hashedBytes :: Digest SHA256
      hashedBytes = hash input
      encodedToken = B64.encode (BS.pack (show hashedBytes))
  return $ pack $ BS.unpack encodedToken
  where
    userIdBytes = BS.pack $ show user.id
    emailBytes = TE.encodeUtf8 user.email
