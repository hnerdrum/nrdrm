{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Ingredient
    (
      Ingredient(..)
    , Unit(..)
    ) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text
import Data.Time
import Data.UUID
import Database.PostgreSQL.Simple.FromField

data Unit = G | Ml | Tsp | Tbsp | Qty deriving (Show)

$(deriveJSON defaultOptions ''Unit)

instance FromField Unit where
  fromField f bs
    | bs == Nothing     = returnError UnexpectedNull f ""
    | bs == Just "g"    = pure G
    | bs == Just "ml"   = pure Ml
    | bs == Just "tsp"  = pure Tsp
    | bs == Just "tbsp" = pure Tbsp
    | bs == Just "qty"  = pure Qty
    | otherwise         = returnError ConversionFailed f ""

data Ingredient = Ingredient
  { id          :: UUID
  , createdAt   :: UTCTime
  , updatedAt   :: UTCTime
  , name        :: Text
  , amount      :: Int
  , unit        :: Unit
  } deriving (Show)

$(deriveJSON defaultOptions ''Ingredient)
