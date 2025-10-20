module ORM.Schema.Ingredient
  ( IngredientTable (..),
    IngredientRow (..),
    ingredientId,
    ingredientCreatedAt,
    ingredientUpdatedAt,
    ingredientName,
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core

data IngredientTable = IngredientTable

type instance PrimaryKeyType IngredientTable = UUID

instance Entity IngredientTable where
  tableName = "ingredient"
  primaryKey = ingredientId

data IngredientRow = IngredientRow
  { id :: UUID,
    createdAt :: UTCTime,
    updatedAt :: UTCTime,
    name :: Text
  }
  deriving (Show)

instance FromRow IngredientRow where
  fromRow = IngredientRow <$> field <*> field <*> field <*> field

ingredientId :: Field IngredientTable UUID
ingredientId = Field "id" "id"

ingredientCreatedAt :: Field IngredientTable UTCTime
ingredientCreatedAt = Field "createdAt" "created_at"

ingredientUpdatedAt :: Field IngredientTable UTCTime
ingredientUpdatedAt = Field "updatedAt" "updated_at"

ingredientName :: Field IngredientTable Text
ingredientName = Field "name" "name"

