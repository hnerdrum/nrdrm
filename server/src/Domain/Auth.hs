{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.Auth
(
  LoginInput(..)
, generateToken
, loginUser
, upsertUserAuthToken
) where

import Control.Monad.Reader (liftIO)
import Crypto.BCrypt (validatePassword)
import Crypto.Hash (Digest, SHA256, hash)
import Data.Aeson
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8 as BS
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Data.Text
import qualified Data.Text.Encoding as TE
import Database.Auth (AuthTokenStatus(..))
import Database.User (DbUser(..))
import Domain.Errors (UserError(..))
import Domain.User (User(..), getUserByEmail, fromDbUser)

type Token = Text

data LoginInput = LoginInput
  { email    :: Text
  , password :: Text
  } deriving (Show)

instance FromJSON LoginInput where
  parseJSON = withObject "LoginInput" $ \obj -> do
    emailValue <- obj .: "email"
    passwordValue <- obj .: "password"
    return $ LoginInput
      { email    = emailValue
      , password = passwordValue
      }

loginUser :: Pool PGSimple.Connection -> LoginInput -> IO (Either UserError User)
loginUser pool loginInput = do
  eitherUser <- liftIO $ getUserByEmail pool loginInput.email
  return $ eitherUser >>= (verifyUserLogin loginInput)

verifyUserLogin :: LoginInput -> DbUser -> Either UserError User
verifyUserLogin loginInput user = fmap fromDbUser $ validateUserPassword user loginInput.password

validateUserPassword :: DbUser -> Text -> Either UserError DbUser
validateUserPassword user inputPassword
  | validatePassword (TE.encodeUtf8 user.passwordHash) (TE.encodeUtf8 inputPassword) = Right user
  | otherwise = Left WrongPasswordError

upsertUserAuthToken :: Pool PGSimple.Connection -> User -> Token -> IO ()
upsertUserAuthToken pool user token =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      _ <- PGSimple.execute conn
         [sql|
           INSERT INTO auth_token (value, status, user_id)
           VALUES (?, ?, ?)
           ON CONFLICT (value, user_id)
           DO UPDATE SET status = EXCLUDED.status
         |] $ (token, NORMAL, user.id)
      return ()

generateToken :: User -> IO Token
generateToken user = do
    let input = BS.concat [userIdBytes, emailBytes]
        hashedBytes :: Digest SHA256
        hashedBytes = hash input
        encodedToken = B64.encode (BS.pack (show hashedBytes))
    return $ pack $ BS.unpack $ encodedToken
  where
    userIdBytes = BS.pack $ show user.id
    emailBytes = TE.encodeUtf8 user.email
