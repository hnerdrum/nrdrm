{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.User
(
  User(..)
, getUserByEmail
, fromDbUser
) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text
import Data.UUID
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.User (DbUser(..))
import Domain.Errors (UserError(..))

data User = User
  { id    :: UUID
  , email :: Text
  } deriving (Show)

$(deriveJSON defaultOptions ''User)


getUserByEmail :: Pool PGSimple.Connection -> Text -> IO (Either UserError DbUser)
getUserByEmail pool userEmail =
  withResource pool $ \conn -> do
    dbUsers <- PGSimple.query conn
      [sql|
        SELECT * FROM "user"
        WHERE email = ?
      |] $ PGSimple.Only userEmail
    return $ reduceDbUsers dbUsers

reduceDbUsers :: [DbUser] -> Either UserError DbUser
reduceDbUsers [] = Left UserNotFound
reduceDbUsers [dbUser] = Right dbUser
reduceDbUsers _ = Left MultipleUsersFound

fromDbUser :: DbUser -> User
fromDbUser dbUser =
  User
    { id = dbUser.id
    , email = dbUser.email
    }
