{-# LANGUAGE OverloadedStrings #-}

module Domain.Unit
  ( Unit (..),
    fromDbUnit,
    toDbUnit,
  )
where

import Data.Aeson (FromJSON (..), ToJSON (..), Value (String), withText)
import qualified Data.Text as T
import qualified ORM.Client.Recipe as ORM

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

toDbUnit :: Unit -> ORM.Unit
toDbUnit G = ORM.G
toDbUnit Ml = ORM.Ml
toDbUnit Tsp = ORM.Tsp
toDbUnit Tbsp = ORM.Tbsp
toDbUnit Qty = ORM.Qty

fromDbUnit :: ORM.Unit -> Unit
fromDbUnit ORM.G = G
fromDbUnit ORM.Ml = Ml
fromDbUnit ORM.Tsp = Tsp
fromDbUnit ORM.Tbsp = Tbsp
fromDbUnit ORM.Qty = Qty
