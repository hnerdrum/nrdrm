{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Database.Recipe
(
  DbRecipeIngredient(..)
, CreateRecipeInput(..)
, CreateRecipeIngredientInput(..)
, getCreateRecipeInput
) where

import Data.Aeson
import Data.Text
import Data.Time
import Data.UUID
import Database.Ingredient (Unit(..))
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
getCreateRecipeInput uuid input = (uuid, name input, description input)

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
