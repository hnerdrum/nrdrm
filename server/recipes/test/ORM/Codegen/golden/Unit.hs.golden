{-# LANGUAGE OverloadedStrings #-}

module ORM.Schema.Unit
  ( Unit (..),
    unitToString
  )
where

import Data.Maybe (isNothing)
import Data.Text (Text)
import Database.PostgreSQL.Simple.FromField
  ( FromField (..),
    ResultError (ConversionFailed, UnexpectedNull),
    returnError,
  )
import Database.PostgreSQL.Simple.ToField (ToField (..), toField)

data Unit = G | Ml | Tsp | Tbsp | Qty
  deriving (Show, Eq)


instance FromField Unit where
  fromField f bs
    | isNothing bs = returnError UnexpectedNull f ""
    | bs == Just "g" = pure G
    | bs == Just "ml" = pure Ml
    | bs == Just "tsp" = pure Tsp
    | bs == Just "tbsp" = pure Tbsp
    | bs == Just "qty" = pure Qty
    | otherwise = returnError ConversionFailed f ""


instance ToField Unit where
  toField = toField . unitToString


unitToString :: Unit -> Text
unitToString G = "g"
unitToString Ml = "ml"
unitToString Tsp = "tsp"
unitToString Tbsp = "tbsp"
unitToString Qty = "qty"

