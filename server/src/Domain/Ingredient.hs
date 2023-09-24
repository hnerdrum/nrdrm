{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Domain.Ingredient
    (
      RecipeIngredient(..)
    , getAllIngredients
    , toRecipeIngredient
    , getIngredient
    , createIngredient
    , updateIngredient
    ) where

import Data.Aeson
import Data.Aeson.TH
import Data.Text hiding (null, length, head)
import Data.Time
import Data.UUID hiding (null)
import qualified Data.UUID.V4 as V4
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.Ingredient (Unit(..), Ingredient(..), CreateIngredientInput(..), UpdateIngredientInput(..))
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
  withResource pool $ \conn -> getIngredientById conn ingredientId

createIngredient :: Pool PGSimple.Connection -> CreateIngredientInput -> IO (Either IngredientError Ingredient)
createIngredient pool ingredient =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      ingredientId <- V4.nextRandom
      _ <- PGSimple.execute conn
        [sql|
          INSERT INTO ingredient (id, name)
          VALUES (?, ?)
        |] (ingredientId, ingredient.name)
      getIngredientById conn ingredientId

updateIngredient :: Pool PGSimple.Connection -> UUID -> UpdateIngredientInput -> IO (Either IngredientError Ingredient)
updateIngredient pool ingredientId ingredient =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      now <- getCurrentTime
      _ <- PGSimple.execute conn
        [sql|
          UPDATE ingredient SET updated_at = ?, name = ?
          WHERE id = ?
        |] (now, ingredient.name, ingredientId)
      getIngredientById conn ingredientId

getIngredientById :: PGSimple.Connection -> UUID -> IO (Either IngredientError Ingredient)
getIngredientById conn ingredientId = do
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