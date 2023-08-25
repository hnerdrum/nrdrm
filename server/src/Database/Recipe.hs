
module Database.Recipe
(
  DbRecipeIngredient(..)
) where

import Data.Text
import Data.Time
import Data.UUID
import Database.Ingredient (Unit(..))
import Database.PostgreSQL.Simple.FromRow

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