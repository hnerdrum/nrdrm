{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Database.Auth
(
  AuthTokenStatus(..)
) where

import Data.Maybe
import Database.PostgreSQL.Simple.FromField
import Database.PostgreSQL.Simple.ToField

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