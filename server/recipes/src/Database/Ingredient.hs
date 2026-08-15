module Database.Ingredient
  ( Unit (..),
    unitToString,
    CreateIngredientInput (..),
    UpdateIngredientInput (..),
  )
where

import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Text (Text)
import ORM.Schema.Unit (Unit (..), unitToString)

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
