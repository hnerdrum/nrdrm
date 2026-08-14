{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Schema.RecipeIngredient
  ( RecipeIngredientTable (..),
    RecipeIngredientRow (..),
    RecipeIngredientCreate (..),
    RecipeIngredientUpdate (..),
    recipeIngredientRecipeId,
    recipeIngredientIngredientId,
    recipeIngredientAmount,
    recipeIngredientUnit,
    riIngredient
  )
where

import Data.UUID (UUID)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Core
import ORM.Insert (Insertable (..), emptyInsert, set)
import ORM.Update (Updatable (..), emptyUpdate, setFieldMaybe)
import ORM.Relation (BelongsTo (..), JoinType (..))
import Database.Ingredient (Unit)
import ORM.Schema.Ingredient (IngredientTable)
import qualified ORM.Schema.Ingredient as Ingredient

data RecipeIngredientTable = RecipeIngredientTable

type instance PrimaryKeyType RecipeIngredientTable = UUID

instance Entity RecipeIngredientTable where
  tableName = "recipe_ingredient"
  primaryKey = recipeIngredientRecipeId

instance Insertable RecipeIngredientTable where
  type CreateInput RecipeIngredientTable = RecipeIngredientCreate
  toInsertBuilder input =
    set recipeIngredientRecipeId input.recipeId $
      set recipeIngredientIngredientId input.ingredientId $
      set recipeIngredientAmount input.amount $
      set recipeIngredientUnit input.unit $
      emptyInsert @RecipeIngredientTable


instance Updatable RecipeIngredientTable where
  type UpdateInput RecipeIngredientTable = RecipeIngredientUpdate
  updatedAtField = Nothing
  toUpdateBuilder input =
    setFieldMaybe recipeIngredientIngredientId input.ingredientId $
      setFieldMaybe recipeIngredientAmount input.amount $
      setFieldMaybe recipeIngredientUnit input.unit $
      emptyUpdate @RecipeIngredientTable


data RecipeIngredientRow = RecipeIngredientRow
  { recipeId :: UUID,
    ingredientId :: UUID,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show, Eq)


data RecipeIngredientCreate = RecipeIngredientCreate
  { recipeId :: UUID,
    ingredientId :: UUID,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show, Eq)


data RecipeIngredientUpdate = RecipeIngredientUpdate
  { ingredientId :: Maybe UUID,
    amount :: Maybe Int,
    unit :: Maybe Unit
  }
  deriving (Show, Eq)


instance FromRow RecipeIngredientRow where
  fromRow = RecipeIngredientRow <$> field <*> field <*> field <*> field


recipeIngredientRecipeId :: Field RecipeIngredientTable UUID
recipeIngredientRecipeId = Field "recipeId" "recipe_id"

recipeIngredientIngredientId :: Field RecipeIngredientTable UUID
recipeIngredientIngredientId = Field "ingredientId" "ingredient_id"

recipeIngredientAmount :: Field RecipeIngredientTable Int
recipeIngredientAmount = Field "amount" "amount"

recipeIngredientUnit :: Field RecipeIngredientTable Unit
recipeIngredientUnit = Field "unit" "unit"

riIngredient :: BelongsTo RecipeIngredientTable IngredientTable UUID
riIngredient =
  BelongsTo
    { foreignKey = recipeIngredientIngredientId,
      references = Ingredient.ingredientId,
      joinType = LeftJoin
    }

