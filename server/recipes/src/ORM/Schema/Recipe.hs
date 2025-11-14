module ORM.Schema.Recipe
  ( RecipeTable (..),
    RecipeRow (..),
    recipeId,
    recipeCreatedAt,
    recipeUpdatedAt,
    recipeName,
    recipeDescription,
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core

data RecipeTable = RecipeTable

type instance PrimaryKeyType RecipeTable = UUID

instance Entity RecipeTable where
  tableName = "recipe"
  primaryKey = recipeId

data RecipeRow = RecipeRow
  { id :: UUID,
    createdAt :: UTCTime,
    updatedAt :: UTCTime,
    name :: Text,
    description :: Text
  }
  deriving (Show)

instance FromRow RecipeRow where
  fromRow = RecipeRow <$> field <*> field <*> field <*> field <*> field

recipeId :: Field RecipeTable UUID
recipeId = Field "id" "id"

recipeCreatedAt :: Field RecipeTable UTCTime
recipeCreatedAt = Field "createdAt" "created_at"

recipeUpdatedAt :: Field RecipeTable UTCTime
recipeUpdatedAt = Field "updatedAt" "updated_at"

recipeName :: Field RecipeTable Text
recipeName = Field "name" "name"

recipeDescription :: Field RecipeTable Text
recipeDescription = Field "description" "description"

