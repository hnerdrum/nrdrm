module Database.User
(
  DbUser(..)
) where

import Data.Text ( Text )
import Data.Time ( UTCTime )
import Data.UUID ( UUID )
import Database.PostgreSQL.Simple.FromRow ( FromRow(..), field )

data DbUser = DbUser
  { id                :: UUID
  , createdAt         :: UTCTime
  , updatedAt         :: UTCTime
  , email             :: Text
  , passwordHash      :: Text
  } deriving (Show)

instance FromRow DbUser where
  fromRow = DbUser <$> field <*> field <*> field <*> field <*> field