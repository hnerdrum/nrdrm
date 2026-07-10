module ORM.Schema.RecipeWithIngredients
  ( RecipeIngredientJoinRow (..),
    RecipeRiJoinRow (..),
  )
where

import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import Database.Ingredient (Unit)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)

data RecipeRiJoinRow = RecipeRiJoinRow
  { recipeId :: UUID,
    recipeCreatedAt :: UTCTime,
    recipeUpdatedAt :: UTCTime,
    recipeName :: Text,
    recipeDescription :: Maybe Text,
    riIngredientId :: Maybe UUID,
    riAmount :: Maybe Int,
    riUnit :: Maybe Unit
  }
  deriving (Show)

instance FromRow RecipeRiJoinRow where
  fromRow =
    RecipeRiJoinRow
      <$> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field

data RecipeIngredientJoinRow = RecipeIngredientJoinRow
  { recipeId :: UUID,
    recipeCreatedAt :: UTCTime,
    recipeUpdatedAt :: UTCTime,
    recipeName :: Text,
    recipeDescription :: Maybe Text,
    ingredientId :: Maybe UUID,
    ingredientCreatedAt :: Maybe UTCTime,
    ingredientUpdatedAt :: Maybe UTCTime,
    ingredientName :: Maybe Text,
    riAmount :: Maybe Int,
    riUnit :: Maybe Unit
  }
  deriving (Show)

instance FromRow RecipeIngredientJoinRow where
  fromRow =
    RecipeIngredientJoinRow
      <$> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
