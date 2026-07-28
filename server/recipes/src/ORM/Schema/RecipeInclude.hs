{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module ORM.Schema.RecipeInclude
  ( RecipeInclude (..),
    RecipeIngredientInclude (..),
    RecipeWithIngredients (..),
    RecipeIngredientItem (..),
  )
where

import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Text (Text)
import Database.Ingredient (Unit (..))
import ORM.Group (groupByKey)
import ORM.Include
  ( BuildJoinChain (..),
    ExecuteInclude (..),
    IncludesJoin (..),
    NestInclude (..),
    applyRootFilter,
  )
import qualified ORM.JoinChain as JoinChain
import qualified ORM.Operations as Ops
import ORM.Schema.Ingredient (IngredientRow (..))
import qualified ORM.Schema.Ingredient as Ingredient
import ORM.Schema.Recipe (RecipeRow (..), RecipeTable, recipeIngredients)
import qualified ORM.Schema.Recipe as Recipe
import ORM.Schema.RecipeIngredient (RecipeIngredientRow (..), riIngredient)
import qualified ORM.Schema.RecipeIngredient as RI
import ORM.Schema.RecipeWithIngredients (RecipeIngredientJoinRow (..), RecipeRiJoinRow (..))

newtype RecipeIngredientInclude = RecipeIngredientInclude
  { ingredient :: Bool
  }
  deriving (Show, Eq)

newtype RecipeInclude = RecipeInclude
  { ingredients :: Maybe RecipeIngredientInclude
  }
  deriving (Show, Eq)

data RecipeIngredientItem = RecipeIngredientItem
  { recipeIngredient :: RecipeIngredientRow,
    ingredient :: Maybe IngredientRow
  }
  deriving (Show)

data RecipeWithIngredients = RecipeWithIngredients
  { recipe :: RecipeRow,
    ingredients :: [RecipeIngredientItem]
  }
  deriving (Show)

instance IncludesJoin RecipeInclude where
  includesJoin RecipeInclude {ingredients} = isJust ingredients

recipeColumns :: [Text]
recipeColumns =
  [ JoinChain.col "r" Recipe.recipeId,
    JoinChain.col "r" Recipe.recipeCreatedAt,
    JoinChain.col "r" Recipe.recipeUpdatedAt,
    JoinChain.col "r" Recipe.recipeName,
    JoinChain.col "r" Recipe.recipeDescription
  ]

recipeRiColumns :: [Text]
recipeRiColumns =
  recipeColumns
    ++ [ JoinChain.col "ri" RI.riIngredientId,
         JoinChain.col "ri" RI.riAmount,
         JoinChain.col "ri" RI.riUnit
       ]

recipeFullColumns :: [Text]
recipeFullColumns =
  recipeColumns
    ++ [ JoinChain.col "i" Ingredient.ingredientId,
         JoinChain.col "i" Ingredient.ingredientCreatedAt,
         JoinChain.col "i" Ingredient.ingredientUpdatedAt,
         JoinChain.col "i" Ingredient.ingredientName,
         JoinChain.col "ri" RI.riAmount,
         JoinChain.col "ri" RI.riUnit
       ]

buildRecipeRiJoin :: JoinChain.JoinChain RecipeTable
buildRecipeRiJoin =
  JoinChain.selectColumns recipeRiColumns $
    JoinChain.buildJoinChainFromHasMany recipeIngredients "r" "ri"

buildRecipeFullJoin :: JoinChain.JoinChain RecipeTable
buildRecipeFullJoin =
  JoinChain.selectColumns recipeFullColumns $
    JoinChain.addBelongsToJoin riIngredient "ri" "i" buildRecipeRiJoin

instance BuildJoinChain RecipeTable RecipeInclude where
  type JoinFlatRow RecipeInclude = RecipeRiJoinRow
  buildJoinChain RecipeInclude {ingredients = Just RecipeIngredientInclude {ingredient = False}} =
    buildRecipeRiJoin
  buildJoinChain RecipeInclude {ingredients = Just RecipeIngredientInclude {ingredient = True}} =
    buildRecipeFullJoin
  buildJoinChain RecipeInclude {ingredients = Nothing} =
    buildRecipeRiJoin

instance NestInclude RecipeInclude RecipeWithIngredients where
  type RootRow RecipeInclude = RecipeRow
  nestRows _ = nestRecipeRiRows
  wrapRoot _ recipe = RecipeWithIngredients {recipe, ingredients = []}

nestRecipeRiRows :: [RecipeRiJoinRow] -> [RecipeWithIngredients]
nestRecipeRiRows =
  map recipeFromRiGroup . groupByKey (.recipeId)

nestRecipeFullRows :: [RecipeIngredientJoinRow] -> [RecipeWithIngredients]
nestRecipeFullRows =
  map recipeFromFullGroup . groupByKey (.recipeId)

recipeFromRiGroup :: [RecipeRiJoinRow] -> RecipeWithIngredients
recipeFromRiGroup rows@(firstRow : _) =
  RecipeWithIngredients
    { recipe = toRecipeRow firstRow,
      ingredients = mapMaybe toRecipeIngredientItemShallow rows
    }
recipeFromRiGroup [] =
  error "recipeFromRiGroup: empty group"

recipeFromFullGroup :: [RecipeIngredientJoinRow] -> RecipeWithIngredients
recipeFromFullGroup rows@(firstRow : _) =
  RecipeWithIngredients
    { recipe = toRecipeRowFromFull firstRow,
      ingredients = mapMaybe toRecipeIngredientItem rows
    }
recipeFromFullGroup [] =
  error "recipeFromFullGroup: empty group"

toRecipeRow :: RecipeRiJoinRow -> RecipeRow
toRecipeRow row =
  RecipeRow
    { id = row.recipeId,
      createdAt = row.recipeCreatedAt,
      updatedAt = row.recipeUpdatedAt,
      name = row.recipeName,
      description = row.recipeDescription
    }

toRecipeRowFromFull :: RecipeIngredientJoinRow -> RecipeRow
toRecipeRowFromFull row =
  RecipeRow
    { id = row.recipeId,
      createdAt = row.recipeCreatedAt,
      updatedAt = row.recipeUpdatedAt,
      name = row.recipeName,
      description = row.recipeDescription
    }

toRecipeIngredientItemShallow :: RecipeRiJoinRow -> Maybe RecipeIngredientItem
toRecipeIngredientItemShallow row
  | Just ingredientId <- row.riIngredientId,
    Just amount <- row.riAmount =
      Just
        RecipeIngredientItem
          { recipeIngredient =
              RecipeIngredientRow
                { recipeId = row.recipeId,
                  ingredientId,
                  amount,
                  unit = fromMaybe G row.riUnit
                },
            ingredient = Nothing
          }
  | otherwise = Nothing

toRecipeIngredientItem :: RecipeIngredientJoinRow -> Maybe RecipeIngredientItem
toRecipeIngredientItem row
  | Just amount <- row.riAmount,
    Just ingredientId <- row.ingredientId =
      Just
        RecipeIngredientItem
          { recipeIngredient =
              RecipeIngredientRow
                { recipeId = row.recipeId,
                  ingredientId,
                  amount,
                  unit = fromMaybe G row.riUnit
                },
            ingredient = toIngredientRow row
          }
  | otherwise = Nothing

toIngredientRow :: RecipeIngredientJoinRow -> Maybe IngredientRow
toIngredientRow row
  | Just ingredientId <- row.ingredientId,
    Just createdAt <- row.ingredientCreatedAt,
    Just updatedAt <- row.ingredientUpdatedAt,
    Just name <- row.ingredientName =
      Just IngredientRow {id = ingredientId, createdAt, updatedAt, name}
  | otherwise = Nothing

instance {-# OVERLAPPING #-} ExecuteInclude RecipeTable RecipeInclude RecipeWithIngredients where
  executeInclude pool include modifier =
    case include.ingredients of
      Nothing -> do
        recipes <- Ops.findMany @RecipeTable @RecipeRow pool modifier
        pure $ map (wrapRoot include) recipes
      Just RecipeIngredientInclude {ingredient = False} -> do
        let chain = applyRootFilter buildRecipeRiJoin modifier
        flatRows <- JoinChain.runJoinChain @RecipeRiJoinRow pool chain
        pure $ nestRecipeRiRows flatRows
      Just RecipeIngredientInclude {ingredient = True} -> do
        let chain = applyRootFilter buildRecipeFullJoin modifier
        flatRows <- JoinChain.runJoinChain @RecipeIngredientJoinRow pool chain
        pure $ nestRecipeFullRows flatRows
