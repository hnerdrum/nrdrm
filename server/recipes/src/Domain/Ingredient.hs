{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}

module Domain.Ingredient
  ( Ingredient (..),
    RecipeIngredient (..),
    getAllIngredients,
    fromDbRecipeIngredient,
    getIngredient,
    createIngredient,
    updateIngredient,
    deleteIngredient,
  )
where

import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Pool (Pool, withResource)
import Data.Text (Text)
import Data.Time (getCurrentTime)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as V4
import Database.Ingredient (CreateIngredientInput (..), DbIngredient (..), Unit (..), UpdateIngredientInput (..))
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.Recipe (DbRecipeIngredient (..))
import Domain.Errors (DomainError (..))

data RecipeIngredient = RecipeIngredient
  { id :: UUID,
    name :: Text,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show)

$(deriveJSON defaultOptions ''RecipeIngredient)

data Ingredient = Ingredient
  { id :: UUID,
    name :: Text
  }
  deriving (Show)

$(deriveJSON defaultOptions ''Ingredient)

getAllIngredients :: Pool PGSimple.Connection -> IO [Ingredient]
getAllIngredients pool =
  withResource pool $ \conn -> do
    dbIngredients <- PGSimple.query_ conn "SELECT * from ingredient"
    return $ map fromDbIngredient dbIngredients

getIngredient :: Pool PGSimple.Connection -> UUID -> IO (Either DomainError Ingredient)
getIngredient pool ingredientId =
  withResource pool $ \conn -> getIngredientById conn ingredientId

createIngredient :: Pool PGSimple.Connection -> CreateIngredientInput -> IO (Either DomainError Ingredient)
createIngredient pool ingredient =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      ingredientId <- V4.nextRandom
      _ <-
        PGSimple.execute
          conn
          [sql|
          INSERT INTO ingredient (id, name)
          VALUES (?, ?)
        |]
          (ingredientId, ingredient.name)
      getIngredientById conn ingredientId

updateIngredient :: Pool PGSimple.Connection -> UUID -> UpdateIngredientInput -> IO (Either DomainError Ingredient)
updateIngredient pool ingredientId ingredient =
  withResource pool $ \conn ->
    PGSimple.withTransaction conn $ do
      now <- getCurrentTime
      _ <-
        PGSimple.execute
          conn
          [sql|
          UPDATE ingredient SET updated_at = ?, name = ?
          WHERE id = ?
        |]
          (now, ingredient.name, ingredientId)
      getIngredientById conn ingredientId

deleteIngredient :: Pool PGSimple.Connection -> UUID -> IO ()
deleteIngredient pool ingredientId =
  withResource pool $ \conn -> do
    _ <-
      PGSimple.execute
        conn
        [sql|
        DELETE FROM ingredient
        WHERE id = ?
      |]
        $ PGSimple.Only ingredientId
    return ()

getIngredientById :: PGSimple.Connection -> UUID -> IO (Either DomainError Ingredient)
getIngredientById conn ingredientId = do
  dbIngredients <-
    PGSimple.query
      conn
      [sql|
    SELECT id, created_at, updated_at, name
    FROM ingredient
    WHERE id = ?
  |]
      $ PGSimple.Only ingredientId
  return $ reduceDbIngredients dbIngredients

reduceDbIngredients :: [DbIngredient] -> Either DomainError Ingredient
reduceDbIngredients dbIngredients
  | null dbIngredients = Left (NotFoundError "Ingredient could not be found")
  | length dbIngredients == 1 = Right $ fromDbIngredient (head dbIngredients)
  | otherwise = Left (MultipleEntitiesError "Found multiple ingredients with matching ID")

fromDbIngredient :: DbIngredient -> Ingredient
fromDbIngredient dbIngredient =
  Ingredient
    { id = dbIngredient.id,
      name = dbIngredient.name
    }

fromDbRecipeIngredient :: DbRecipeIngredient -> Maybe RecipeIngredient
fromDbRecipeIngredient dbRI = do
  ingredientId <- dbIngredientId dbRI
  ingredientAmount <- dbIngredientAmount dbRI
  ingredientName <- dbIngredientName dbRI
  ingredientUnit <- dbIngredientUnit dbRI

  return
    RecipeIngredient
      { id = ingredientId,
        name = ingredientName,
        amount = ingredientAmount,
        unit = ingredientUnit
      }