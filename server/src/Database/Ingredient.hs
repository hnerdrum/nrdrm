{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}

module Database.Ingredient
(
  Unit(..)
) where

import Data.Aeson
import Data.Aeson.TH
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