{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.Ingredient
    (
      RecipeIngredient(..)
    , getAllIngredients
    , toRecipeIngredient
    , getIngredient
    ) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text hiding (null, length, head)
import Data.Time
import Data.UUID hiding (null)
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.Ingredient (Unit(..), Ingredient(..))
import Database.Recipe (DbRecipeIngredient(..))
import Domain.Errors (IngredientError(..))

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

getIngredient :: Pool PGSimple.Connection -> UUID -> IO (Either IngredientError Ingredient)
getIngredient pool ingredientId =
  withResource pool $ \conn -> do
    dbIngredients <- PGSimple.query conn
      [sql|
      SELECT id, created_at, updated_at, name
      FROM ingredient
      WHERE id = ?
    |] $ PGSimple.Only ingredientId
    return $ reduceDbIngredients dbIngredients

reduceDbIngredients :: [Ingredient] -> Either IngredientError Ingredient
reduceDbIngredients dbIngredients
  | null dbIngredients        = Left IngredientNotFound
  | length dbIngredients == 1 = Right $ head dbIngredients
  | otherwise                 = Left MultipleIngredientsFound

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