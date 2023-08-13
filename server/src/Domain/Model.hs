{-# LANGUAGE TemplateHaskell #-}

module Domain.Model
    (
      User(..)
    ) where

import Data.Aeson
import Data.Aeson.TH

data User = User
  { id        :: Int
  , firstName  :: String
  , lastName  :: String
  } deriving (Eq, Show)

$(deriveJSON defaultOptions ''User)