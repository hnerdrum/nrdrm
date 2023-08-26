{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Ingredient
    (
      RecipeIngredient(..)
    , getAllIngredients
    , toRecipeIngredient
    ) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text
import Data.Time
import Data.UUID
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.Ingredient (Unit(..), Ingredient(..))
import Database.Recipe (DbRecipeIngredient(..))

data RecipeIngredient = RecipeIngredient
  { id          :: UUID
  , createdAt   :: UTCTime
  , updatedAt   :: UTCTime
  , name        :: Text
  , amount      :: Int
  , unit        :: Unit
  } deriving (Show)

$(deriveJSON defaultOptions ''RecipeIngredient)

getAllIngredients :: Pool PGSimple.Connection -> IO [Ingredient]
getAllIngredients pool =
  withResource pool $ \conn -> do
    PGSimple.query_ conn "SELECT * from ingredient"

toRecipeIngredient :: DbRecipeIngredient -> Maybe RecipeIngredient
toRecipeIngredient dbRI = do
  ingredientId <- dbIngredientId dbRI
  ingredientCreatedAt <- dbIngredientCreatedAt dbRI
  ingredientUpdatedAt <- dbIngredientUpdatedAt dbRI
  ingredientAmount <- dbIngredientAmount dbRI
  ingredientName <- dbIngredientName dbRI
  ingredientUnit <- dbIngredientUnit dbRI

  return RecipeIngredient
    { id = ingredientId
    , createdAt = ingredientCreatedAt
    , updatedAt = ingredientUpdatedAt
    , name = ingredientName
    , amount = ingredientAmount
    , unit = ingredientUnit
    }