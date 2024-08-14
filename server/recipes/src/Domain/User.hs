{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.User
  ( User (..),
    getUserByEmail,
    fromDbUser,
  )
where

import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Pool (Pool, withResource)
import Data.Text (Text)
import Data.UUID (UUID)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.User (DbUser (..))
import Domain.Errors (DomainError (..))

data User = User
  { id :: UUID,
    email :: Text
  }
  deriving (Show)

$(deriveJSON defaultOptions ''User)

getUserByEmail :: Pool PGSimple.Connection -> Text -> IO (Either DomainError DbUser)
getUserByEmail pool userEmail =
  withResource pool $ \conn -> do
    dbUsers <-
      PGSimple.query
        conn
        [sql|
        SELECT * FROM "user_account"
        WHERE email = ?
      |]
        $ PGSimple.Only userEmail
    return $ reduceDbUsers dbUsers

reduceDbUsers :: [DbUser] -> Either DomainError DbUser
reduceDbUsers [] = Left (NotFoundError "User could not be found")
reduceDbUsers [dbUser] = Right dbUser
reduceDbUsers _ = Left (MultipleEntitiesError "Found multiple users with matching email")

fromDbUser :: DbUser -> User
fromDbUser dbUser =
  User
    { id = dbUser.id,
      email = dbUser.email
    }
