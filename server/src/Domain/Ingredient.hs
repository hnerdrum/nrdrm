{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Ingredient
    (
      Ingredient(..)
    , toIngredient
    ) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text
import Data.Time
import Data.UUID
import Database.Ingredient (Unit(..))
import Database.Recipe (DbRecipeIngredient(..))

data Ingredient = Ingredient
  { id          :: UUID
  , createdAt   :: UTCTime
  , updatedAt   :: UTCTime
  , name        :: Text
  , amount      :: Int
  , unit        :: Unit
  } deriving (Show)

$(deriveJSON defaultOptions ''Ingredient)

toIngredient :: DbRecipeIngredient -> Maybe Ingredient
toIngredient dbRI = do
  ingredientId <- dbIngredientId dbRI
  ingredientCreatedAt <- dbIngredientCreatedAt dbRI
  ingredientUpdatedAt <- dbIngredientUpdatedAt dbRI
  ingredientAmount <- dbIngredientAmount dbRI
  ingredientName <- dbIngredientName dbRI
  ingredientUnit <- dbIngredientUnit dbRI

  return Ingredient
    { id = ingredientId
    , createdAt = ingredientCreatedAt
    , updatedAt = ingredientUpdatedAt
    , name = ingredientName
    , amount = ingredientAmount
    , unit = ingredientUnit
    }