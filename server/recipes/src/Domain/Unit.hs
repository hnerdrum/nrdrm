{-# LANGUAGE OverloadedStrings #-}

module Domain.Unit
  ( Unit (..),
    fromDbUnit,
    toDbUnit,
  )
where

import Data.Aeson (FromJSON (..), ToJSON (..), Value (String), withText)
import qualified Data.Text as T
import qualified Schema.Unit as Schema

data Unit = G | Ml | Tsp | Tbsp | Qty
  deriving (Show, Eq)

instance ToJSON Unit where
  toJSON G = String "g"
  toJSON Ml = String "ml"
  toJSON Tsp = String "tsp"
  toJSON Tbsp = String "tbsp"
  toJSON Qty = String "qty"

instance FromJSON Unit where
  parseJSON =
    withText "Unit" $ \raw ->
      case T.toLower raw of
        "g" -> pure G
        "ml" -> pure Ml
        "tsp" -> pure Tsp
        "tbsp" -> pure Tbsp
        "qty" -> pure Qty
        _ -> fail "unknown Unit"

toDbUnit :: Unit -> Schema.Unit
toDbUnit G = Schema.G
toDbUnit Ml = Schema.Ml
toDbUnit Tsp = Schema.Tsp
toDbUnit Tbsp = Schema.Tbsp
toDbUnit Qty = Schema.Qty

fromDbUnit :: Schema.Unit -> Unit
fromDbUnit Schema.G = G
fromDbUnit Schema.Ml = Ml
fromDbUnit Schema.Tsp = Tsp
fromDbUnit Schema.Tbsp = Tbsp
fromDbUnit Schema.Qty = Qty
