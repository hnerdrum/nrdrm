{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Database.Ingredient
(
  Unit(..)
, unitToString
, Ingredient(..)
, CreateIngredientInput(..)
) where

import Data.Aeson
import Data.Aeson.TH
import Data.Maybe
import Data.Text
import Data.Time
import Data.UUID
import Database.PostgreSQL.Simple.FromField
import Database.PostgreSQL.Simple.FromRow

data Unit = G | Ml | Tsp | Tbsp | Qty deriving (Show)

$(deriveJSON defaultOptions ''Unit)

data Ingredient = Ingredient
  { id        :: UUID
  , createdAt :: UTCTime
  , updatedAt :: UTCTime
  , name      :: Text
  } deriving (Show)

$(deriveJSON defaultOptions ''Ingredient)

instance FromRow Ingredient where
  fromRow = Ingredient <$> field <*> field <*> field <*> field

newtype CreateIngredientInput = CreateIngredientInput
  { name :: Text
  } deriving (Show)

instance FromJSON CreateIngredientInput where
  parseJSON = withObject "CreateIngredientInput" $ \obj -> do
    nameValue <- obj .: "name"
    return $ CreateIngredientInput { name = nameValue }

instance FromField Unit where
  fromField f bs
    | isNothing bs      = returnError UnexpectedNull f ""
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
