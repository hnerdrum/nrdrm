{-# LANGUAGE OverloadedRecordDot #-}

module Database.Recipe
(
  DbRecipeIngredient(..)
, CreateRecipeInput(..)
, CreateRecipeIngredientInput(..)
, getCreateRecipeInput
, getCreateRecipeIngredientInput
, UpdateRecipeInput(..)
, UpdateRecipeIngredientInput(..)
, getUpdateRecipeIngredientInput
) where

import Data.Aeson ( FromJSON(parseJSON), (.:), (.:?), withObject )
import Data.Text ( Text )
import Data.Time ( UTCTime )
import Data.UUID ( UUID )
import Database.Ingredient (Unit(..), unitToString)
import Database.PostgreSQL.Simple.FromRow ( FromRow(..), field )

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

data UpdateRecipeInput = UpdateRecipeInput
  { name        :: Maybe Text
  , description :: Maybe Text
  , ingredients :: Maybe [UpdateRecipeIngredientInput]
  } deriving (Show)

instance FromJSON UpdateRecipeInput where
  parseJSON = withObject "UpdateRecipeInput" $ \obj -> do
    nameValue <- obj .:? "name"
    descriptionValue <- obj .:? "description"
    ingredientsValue <- obj .:? "ingredients"
    return $ UpdateRecipeInput
      { name        = nameValue
      , description = descriptionValue
      , ingredients = ingredientsValue
      }

getCreateRecipeInput :: UUID -> CreateRecipeInput -> (UUID, Text, Text)
getCreateRecipeInput recipeId input = (recipeId, input.name, input.description)

getCreateRecipeIngredientInput :: UUID -> CreateRecipeInput -> [(UUID, UUID, Int, Text)]
getCreateRecipeIngredientInput recipeId input =
  map (\ingredient -> (recipeId, ingredient.id, ingredient.amount, unitToString ingredient.unit)) input.ingredients

data CreateRecipeIngredientInput = CreateRecipeIngredientInput
  { id :: UUID
  , amount       :: Int
  , unit         :: Unit
  } deriving (Show)

instance FromJSON CreateRecipeIngredientInput where
  parseJSON = withObject "CreateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "id"
    amountValue <- obj .: "amount"
    unitValue <- obj .: "unit"
    return $ CreateRecipeIngredientInput
      { id   = ingredientIdValue
      , amount         = amountValue
      , unit           = unitValue
      }

data UpdateRecipeIngredientInput = UpdateRecipeIngredientInput
 { id     :: UUID
 , amount :: Maybe Int
 , unit   :: Maybe Unit
 } deriving (Show)

instance FromJSON UpdateRecipeIngredientInput where
  parseJSON = withObject "UpdateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "id"
    amountValue <- obj .:? "amount"
    unitValue <- obj .:? "unit"
    return $ UpdateRecipeIngredientInput
      { id   = ingredientIdValue
      , amount         = amountValue
      , unit           = unitValue
      }

getUpdateRecipeIngredientInput :: UUID -> UpdateRecipeInput -> [(UUID, UUID, Maybe Int, Maybe Text)]
getUpdateRecipeIngredientInput recipeId input = case input.ingredients of
  Nothing -> []
  Just ings -> map (\ingredient ->
    (recipeId, ingredient.id, ingredient.amount, fmap unitToString ingredient.unit)) ings
