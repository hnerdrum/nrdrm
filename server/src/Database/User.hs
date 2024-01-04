module Database.User
(
  DbUser(..)
) where

import Data.Text
import Data.Time
import Data.UUID
import Database.PostgreSQL.Simple.FromRow

data DbUser = DbUser
  { id                :: UUID
  , createdAt         :: UTCTime
  , updatedAt         :: UTCTime
  , email             :: Text
  , passwordHash      :: Text
  } deriving (Show)

instance FromRow DbUser where
  fromRow = DbUser <$> field <*> field <*> field <*> field <*> field