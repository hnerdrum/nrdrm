module Database.Recipe
  ( CreateRecipeInput (..),
    CreateRecipeIngredientInput (..),
    UpdateRecipeInput (..),
    UpdateRecipeIngredientInput (..),
  )
where

import Data.Aeson (FromJSON (parseJSON), withObject, (.:), (.:?))
import Data.Text (Text)
import Data.UUID (UUID)
import Database.Ingredient (Unit (..))

data CreateRecipeInput = CreateRecipeInput
  { name :: Text,
    description :: Text,
    ingredients :: [CreateRecipeIngredientInput]
  }
  deriving (Show)

instance FromJSON CreateRecipeInput where
  parseJSON = withObject "CreateRecipeInput" $ \obj -> do
    nameValue <- obj .: "name"
    descriptionValue <- obj .: "description"
    ingredientsValue <- obj .: "ingredients"
    return $
      CreateRecipeInput
        { name = nameValue,
          description = descriptionValue,
          ingredients = ingredientsValue
        }

data UpdateRecipeInput = UpdateRecipeInput
  { name :: Maybe Text,
    description :: Maybe Text,
    ingredients :: Maybe [UpdateRecipeIngredientInput]
  }
  deriving (Show)

instance FromJSON UpdateRecipeInput where
  parseJSON = withObject "UpdateRecipeInput" $ \obj -> do
    nameValue <- obj .:? "name"
    descriptionValue <- obj .:? "description"
    ingredientsValue <- obj .:? "ingredients"
    return $
      UpdateRecipeInput
        { name = nameValue,
          description = descriptionValue,
          ingredients = ingredientsValue
        }

data CreateRecipeIngredientInput = CreateRecipeIngredientInput
  { id :: UUID,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show)

instance FromJSON CreateRecipeIngredientInput where
  parseJSON = withObject "CreateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "id"
    amountValue <- obj .: "amount"
    unitValue <- obj .: "unit"
    return $
      CreateRecipeIngredientInput
        { id = ingredientIdValue,
          amount = amountValue,
          unit = unitValue
        }

data UpdateRecipeIngredientInput = UpdateRecipeIngredientInput
  { id :: UUID,
    amount :: Maybe Int,
    unit :: Maybe Unit
  }
  deriving (Show)

instance FromJSON UpdateRecipeIngredientInput where
  parseJSON = withObject "UpdateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "id"
    amountValue <- obj .:? "amount"
    unitValue <- obj .:? "unit"
    return $
      UpdateRecipeIngredientInput
        { id = ingredientIdValue,
          amount = amountValue,
          unit = unitValue
        }
