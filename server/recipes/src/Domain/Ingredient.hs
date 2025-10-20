{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeApplications #-}

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
import Data.Bifunctor (bimap)
import Data.Either.Combinators (mapLeft)
import Data.Pool (Pool, withResource)
import Data.Text (Text)
import Data.Time (getCurrentTime)
import Data.UUID (UUID)
import Database.Ingredient (CreateIngredientInput (..), Unit (..), UpdateIngredientInput (..))
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.Recipe (DbRecipeIngredient (..))
import Domain.Errors (AppError (..), DomainError (..))
import ORM (ToInsert (..))
import qualified ORM
import ORM.Schema.Ingredient (IngredientRow (..), IngredientTable, ingredientName)

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

instance ToInsert CreateIngredientInput IngredientTable where
  toInsertBuilder input =
    ORM.setValue ingredientName input.name

getAllIngredients :: Pool PGSimple.Connection -> IO [Ingredient]
getAllIngredients pool = do
  ingredientRows <- ORM.findAll @IngredientTable pool
  return $ map fromIngredientRow ingredientRows

getIngredient :: Pool PGSimple.Connection -> UUID -> IO (Either AppError Ingredient)
getIngredient pool ingredientId =
  bimap fromIngredientError fromIngredientRow
    <$> ORM.findUniqueOrError @IngredientTable pool ingredientId

createIngredient :: Pool PGSimple.Connection -> CreateIngredientInput -> IO (Either AppError Ingredient)
createIngredient pool input =
  bimap fromIngredientError fromIngredientRow
    <$> ORM.createWith @CreateIngredientInput @IngredientTable @IngredientRow pool input

updateIngredient :: Pool PGSimple.Connection -> UUID -> UpdateIngredientInput -> IO (Either AppError Ingredient)
updateIngredient pool ingredientId ingredient = do
  now <- getCurrentTime
  rowsAffected <- withResource pool $ \conn ->
    PGSimple.execute
      conn
      [sql|
        UPDATE ingredient SET updated_at = ?, name = ?
        WHERE id = ?
      |]
      (now, ingredient.name, ingredientId)
  if rowsAffected == 0
    then return $ Left $ AppError NotFoundError "Ingredient could not be found" (object ["ingredientId" .= ingredientId])
    else
      return $
        Right $
          Ingredient
            { id = ingredientId,
              name = ingredient.name
            }

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

fromIngredientRow :: IngredientRow -> Ingredient
fromIngredientRow row =
  Ingredient
    { id = row.id,
      name = row.name
    }

fromIngredientError :: ORM.ORMError -> AppError
fromIngredientError err =
  case err of
    ORM.RecordNotFound ingredientId -> AppError NotFoundError "Ingredient could not be found" (object ["ingredientId" .= ingredientId])
    ORM.MultipleRecordsFound ingredientId -> AppError MultipleEntitiesError "Found multiple ingredients with matching ID" (object ["ingredientId" .= ingredientId])

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