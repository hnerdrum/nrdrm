{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Domain.User
(
  User(..)
) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text
import Data.UUID

import Database.User (DbUser(..))

data User = User
  { id    :: UUID
  , email :: Text
  } deriving (Show)

$(deriveJSON defaultOptions ''DbUser)

fromDbUser :: DbUser -> User
fromDbUser dbUser =
  User
    { id = dbUser.id
    , email = dbUser.email
    }