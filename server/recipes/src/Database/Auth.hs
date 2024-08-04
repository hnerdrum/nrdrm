module Database.Auth
(
   DbAuthToken(..)
 , AuthTokenStatus(..)
) where

import Data.Maybe ( isNothing )
import Data.Text ( Text )
import Data.Time ( UTCTime )
import Data.UUID ( UUID )
import Database.PostgreSQL.Simple.FromField
    ( ResultError(ConversionFailed, UnexpectedNull),
      FromField(..),
      returnError )
import Database.PostgreSQL.Simple.ToField
    ( Action(Escape), ToField(..) )
import Database.PostgreSQL.Simple.FromRow ( FromRow(..), field )

data DbAuthToken = DbAuthToken
  { id         :: UUID
  , createdAt  :: UTCTime
  , updatedAt  :: UTCTime
  , value      :: Text
  , userId     :: UUID
  } deriving (Show)

instance FromRow DbAuthToken where
  fromRow = DbAuthToken <$> field <*> field <*> field <*> field <*> field

data AuthTokenStatus = NORMAL | WITHDRAWN | EXPIRED deriving (Show)

instance FromField AuthTokenStatus where
  fromField f bs
    | isNothing bs             = returnError UnexpectedNull f ""
    | bs == Just "NORMAL"      = pure NORMAL
    | bs == Just "WITHDRAWN"   = pure WITHDRAWN
    | bs == Just "EXPIRED"     = pure EXPIRED
    | otherwise                = returnError ConversionFailed f ""

instance ToField AuthTokenStatus where
    toField NORMAL   = Escape "NORMAL"
    toField WITHDRAWN = Escape "WITHDRAWN"
    toField EXPIRED  = Escape "EXPIRED"