{-# LANGUAGE TemplateHaskell #-}

module Domain.Model
    (
      Recipe(..)
    ) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text
import Data.Time
import Data.UUID
import Database.PostgreSQL.Simple.FromRow

data Recipe = Recipe
  { id          :: UUID
  , createdAt   :: UTCTime
  , updatedAt   :: UTCTime
  , name        :: Text
  , description :: Text
  } deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

instance FromRow Recipe where
  fromRow = Recipe <$> field <*> field <*> field <*> field <*> field