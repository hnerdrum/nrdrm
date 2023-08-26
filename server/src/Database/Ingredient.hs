{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}

module Database.Ingredient
(
  Unit(..)
, unitToString
) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text
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

unitToString :: Unit -> Text
unitToString G = "g"
unitToString Ml = "ml"
unitToString Tsp = "tsp"
unitToString Tbsp = "tbsp"
unitToString Qty = "qty"
