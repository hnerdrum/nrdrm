{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Database.Recipe
(
  DbRecipeIngredient(..)
, CreateRecipeInput(..)
, CreateRecipeIngredientInput(..)
, getCreateRecipeInput
, getCreateRecipeIngredientInput
) where

import Data.Aeson
import Data.Text hiding (map)
import Data.Time
import Data.UUID
import Database.Ingredient (Unit(..), unitToString)
import Database.PostgreSQL.Simple.FromRow

data DbRecipeIngredient = DbRecipeIngredient
  { dbRecipeId :: UUID
  , dbRecipeCreatedAt :: UTCTime
  , dbRecipeUpdatedAt :: UTCTime
  , dbRecipeName      :: Text
  , dbRecipeDescription :: Text
  , dbIngredientId :: Maybe UUID
  , dbIngredientCreatedAt :: Maybe UTCTime
  , dbIngredientUpdatedAt :: Maybe UTCTime
  , dbIngredientName :: Maybe Text
  , dbIngredientAmount :: Maybe Int
  , dbIngredientUnit :: Maybe Unit
  } deriving (Show)

instance FromRow DbRecipeIngredient where
  fromRow = DbRecipeIngredient <$> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field

data CreateRecipeInput = CreateRecipeInput
  { name        :: Text
  , description :: Text
  , ingredients :: [CreateRecipeIngredientInput]
  } deriving (Show)

instance FromJSON CreateRecipeInput where
  parseJSON = withObject "CreateRecipeInput" $ \obj -> do
    nameValue <- obj .: "name"
    descriptionValue <- obj .: "description"
    ingredientsValue <- obj .: "ingredients"
    return $ CreateRecipeInput
      { name        = nameValue
      , description = descriptionValue
      , ingredients = ingredientsValue
      }

getCreateRecipeInput :: UUID -> CreateRecipeInput -> (UUID, Text, Text)
getCreateRecipeInput recipeId input = (recipeId, name input, description input)

getCreateRecipeIngredientInput :: UUID -> CreateRecipeInput -> [(UUID, UUID, Int, Text)]
getCreateRecipeIngredientInput recipeId input =
  map (\ingredient -> (recipeId, ingredientId ingredient, amount ingredient, unitToString $ unit ingredient)) (ingredients input)

data CreateRecipeIngredientInput = CreateRecipeIngredientInput
  { ingredientId :: UUID
  , amount       :: Int
  , unit         :: Unit
  } deriving (Show)

instance FromJSON CreateRecipeIngredientInput where
  parseJSON = withObject "CreateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "ingredientId"
    amountValue <- obj .: "amount"
    unitValue <- obj .: "unit"
    return $ CreateRecipeIngredientInput
      { ingredientId   = ingredientIdValue
      , amount         = amountValue
      , unit           = unitValue
      }
