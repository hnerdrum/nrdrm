module Database.Ingredient
  ( Unit (..),
    unitToString,
    CreateIngredientInput (..),
    UpdateIngredientInput (..),
  )
where

import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Maybe (isNothing)
import Data.Text (Text)
import Database.PostgreSQL.Simple.FromField
  ( FromField (..),
    ResultError (ConversionFailed, UnexpectedNull),
    returnError,
  )
import Database.PostgreSQL.Simple.ToField (ToField (..))

data Unit = G | Ml | Tsp | Tbsp | Qty deriving (Show, Eq)

$(deriveJSON defaultOptions ''Unit)

newtype CreateIngredientInput = CreateIngredientInput
  { name :: Text
  }
  deriving (Show)

instance FromJSON CreateIngredientInput where
  parseJSON = withObject "CreateIngredientInput" $ \obj -> do
    nameValue <- obj .: "name"
    return $ CreateIngredientInput {name = nameValue}

newtype UpdateIngredientInput = UpdateIngredientInput
  { name :: Text
  }
  deriving (Show)

instance FromJSON UpdateIngredientInput where
  parseJSON = withObject "UpdateIngredientInput" $ \obj -> do
    nameValue <- obj .: "name"
    return $ UpdateIngredientInput {name = nameValue}

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
