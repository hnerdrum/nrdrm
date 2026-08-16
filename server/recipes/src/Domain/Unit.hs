{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Unit
  ( Unit (..),
  )
where

import Data.Aeson (FromJSON (..), ToJSON (..), Value (String), withText)
import ORM (Unit (..))

instance ToJSON Unit where
  toJSON G = String "g"
  toJSON Ml = String "ml"
  toJSON Tsp = String "tsp"
  toJSON Tbsp = String "tbsp"
  toJSON Qty = String "qty"

instance FromJSON Unit where
  parseJSON =
    withText "Unit" $ \case
      "g" -> pure G
      "ml" -> pure Ml
      "tsp" -> pure Tsp
      "tbsp" -> pure Tbsp
      "qty" -> pure Qty
      _ -> fail "unknown Unit"
