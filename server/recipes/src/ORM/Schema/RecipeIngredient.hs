module ORM.Schema.RecipeIngredient
  ( RecipeIngredientTable (..),
    RecipeIngredientRow (..),
    riRecipeId,
    riIngredientId,
    riAmount,
    riUnit,
    riIngredient,
  )
where

import Data.Text (Text)
import Data.UUID (UUID)
import Database.Ingredient (Unit)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Relation (BelongsTo (..), JoinType (..))
import ORM.Schema.Ingredient (IngredientTable)
import qualified ORM.Schema.Ingredient as Ingredient

data RecipeIngredientTable = RecipeIngredientTable

type instance PrimaryKeyType RecipeIngredientTable = UUID

instance Entity RecipeIngredientTable where
  tableName = "recipe_ingredient"
  primaryKey = riRecipeId

data RecipeIngredientRow = RecipeIngredientRow
  { recipeId :: UUID,
    ingredientId :: UUID,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show)

instance FromRow RecipeIngredientRow where
  fromRow = RecipeIngredientRow <$> field <*> field <*> field <*> field

riRecipeId :: Field RecipeIngredientTable UUID
riRecipeId = Field "recipeId" "recipe_id"

riIngredientId :: Field RecipeIngredientTable UUID
riIngredientId = Field "ingredientId" "ingredient_id"

riAmount :: Field RecipeIngredientTable Int
riAmount = Field "amount" "amount"

riUnit :: Field RecipeIngredientTable Text
riUnit = Field "unit" "unit"

riIngredient :: BelongsTo RecipeIngredientTable IngredientTable UUID
riIngredient =
  BelongsTo
    { foreignKey = riIngredientId,
      references = Ingredient.ingredientId,
      joinType = LeftJoin
    }
