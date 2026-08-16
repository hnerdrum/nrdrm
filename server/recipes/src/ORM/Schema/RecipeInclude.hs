{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module ORM.Schema.RecipeInclude
  ( RecipeInclude (..),
    RecipeIngredientInclude (..),
    RecipeIngredientWithIngredient (..),
    RecipeWithIngredients (..),
    RecipeRecipeIngredientJoinRow (..),
    RecipeRecipeIngredientIngredientJoinRow (..)
  )
where

import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Text (Text)
import Data.UUID (UUID)
import Data.Time (UTCTime)
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import ORM.Group (groupByKey)
import ORM.Include
  ( BuildJoinChain (..),
    ExecuteInclude (..),
    IncludesJoin (..),
    NestInclude (..),
    applyRootFilter,
  )
import qualified ORM.JoinChain as JoinChain
import ORM.Operations (findManyConn)
import ORM.Schema.Recipe (RecipeTable, RecipeRow (..), recipeIngredients)
import ORM.Schema.RecipeIngredient (RecipeIngredientRow (..), riIngredient)
import ORM.Schema.Ingredient (IngredientRow (..))
import qualified ORM.Schema.Recipe as Recipe
import qualified ORM.Schema.RecipeIngredient as RecipeIngredient
import qualified ORM.Schema.Ingredient as Ingredient
import ORM.Schema.Unit (Unit)

newtype RecipeIngredientInclude = RecipeIngredientInclude
  { ingredient :: Bool
  }
  deriving (Show, Eq)

newtype RecipeInclude = RecipeInclude
  { ingredients :: Maybe RecipeIngredientInclude
  }
  deriving (Show, Eq)

data RecipeIngredientWithIngredient = RecipeIngredientWithIngredient
  { recipeIngredient :: RecipeIngredientRow,
    ingredient :: Maybe IngredientRow
  }
  deriving (Show, Eq)

data RecipeWithIngredients = RecipeWithIngredients
  { recipe :: RecipeRow,
    ingredients :: [RecipeIngredientWithIngredient]
  }
  deriving (Show, Eq)

instance IncludesJoin RecipeInclude where
  includesJoin RecipeInclude {ingredients} = isJust ingredients

data RecipeRecipeIngredientJoinRow = RecipeRecipeIngredientJoinRow
  { recipeId :: UUID,
    recipeCreatedAt :: UTCTime,
    recipeUpdatedAt :: UTCTime,
    recipeName :: Text,
    recipeDescription :: Maybe Text,
    recipeIngredientId :: Maybe UUID,
    recipeIngredientIngredientId :: Maybe UUID,
    recipeIngredientAmount :: Maybe Int,
    recipeIngredientUnit :: Maybe Unit
  }
  deriving (Show, Eq)

instance FromRow RecipeRecipeIngredientJoinRow where
  fromRow = RecipeRecipeIngredientJoinRow <$> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field

recipeRecipeIngredientColumns :: [Text]
recipeRecipeIngredientColumns =
  [ JoinChain.col "r" Recipe.recipeId,
    JoinChain.col "r" Recipe.recipeCreatedAt,
    JoinChain.col "r" Recipe.recipeUpdatedAt,
    JoinChain.col "r" Recipe.recipeName,
    JoinChain.col "r" Recipe.recipeDescription,
    JoinChain.col "ri" RecipeIngredient.recipeIngredientId,
    JoinChain.col "ri" RecipeIngredient.recipeIngredientIngredientId,
    JoinChain.col "ri" RecipeIngredient.recipeIngredientAmount,
    JoinChain.col "ri" RecipeIngredient.recipeIngredientUnit
  ]

buildRecipeRecipeIngredientJoin :: JoinChain.JoinChain RecipeTable
buildRecipeRecipeIngredientJoin =
  JoinChain.selectColumns recipeRecipeIngredientColumns $
    JoinChain.buildJoinChainFromHasMany recipeIngredients "r" "ri"

data RecipeRecipeIngredientIngredientJoinRow = RecipeRecipeIngredientIngredientJoinRow
  { recipeId :: UUID,
    recipeCreatedAt :: UTCTime,
    recipeUpdatedAt :: UTCTime,
    recipeName :: Text,
    recipeDescription :: Maybe Text,
    recipeIngredientId :: Maybe UUID,
    recipeIngredientIngredientId :: Maybe UUID,
    recipeIngredientAmount :: Maybe Int,
    recipeIngredientUnit :: Maybe Unit,
    ingredientId :: Maybe UUID,
    ingredientCreatedAt :: Maybe UTCTime,
    ingredientUpdatedAt :: Maybe UTCTime,
    ingredientName :: Maybe Text
  }
  deriving (Show, Eq)

instance FromRow RecipeRecipeIngredientIngredientJoinRow where
  fromRow = RecipeRecipeIngredientIngredientJoinRow <$> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field

recipeRecipeIngredientIngredientColumns :: [Text]
recipeRecipeIngredientIngredientColumns =
  recipeRecipeIngredientColumns
    ++ [ JoinChain.col "i" Ingredient.ingredientId,
         JoinChain.col "i" Ingredient.ingredientCreatedAt,
         JoinChain.col "i" Ingredient.ingredientUpdatedAt,
         JoinChain.col "i" Ingredient.ingredientName
       ]

buildRecipeRecipeIngredientIngredientJoin :: JoinChain.JoinChain RecipeTable
buildRecipeRecipeIngredientIngredientJoin =
  JoinChain.selectColumns recipeRecipeIngredientIngredientColumns $
    JoinChain.addBelongsToJoin riIngredient "ri" "i" buildRecipeRecipeIngredientJoin

instance BuildJoinChain RecipeTable RecipeInclude where
  type JoinFlatRow RecipeInclude = RecipeRecipeIngredientJoinRow
  buildJoinChain RecipeInclude {ingredients = Just RecipeIngredientInclude {ingredient = False}} =
    buildRecipeRecipeIngredientJoin
  buildJoinChain RecipeInclude {ingredients = Just RecipeIngredientInclude {ingredient = True}} =
    buildRecipeRecipeIngredientIngredientJoin
  buildJoinChain RecipeInclude {ingredients = Nothing} =
    buildRecipeRecipeIngredientJoin

instance NestInclude RecipeInclude RecipeWithIngredients where
  type RootRow RecipeInclude = RecipeRow
  nestRows _ = nestRecipeRows
  wrapRoot _ recipe = RecipeWithIngredients {recipe, ingredients = []}

nestRecipeRows :: [RecipeRecipeIngredientJoinRow] -> [RecipeWithIngredients]
nestRecipeRows =
  map recipeWithIngredientsFromGroup . groupByKey (.recipeId)

recipeWithIngredientsFromGroup :: [RecipeRecipeIngredientJoinRow] -> RecipeWithIngredients
recipeWithIngredientsFromGroup rows@(firstRow : _) =
  RecipeWithIngredients
    { recipe = toRecipeRow firstRow,
      ingredients = map recipeIngredientWithNoRiIngredient $ mapMaybe toRecipeIngredientRow rows
    }
recipeWithIngredientsFromGroup [] =
  error "recipeWithIngredientsFromGroup: empty group"

recipeIngredientWithNoRiIngredient :: RecipeIngredientRow -> RecipeIngredientWithIngredient
recipeIngredientWithNoRiIngredient recipeIngredient = RecipeIngredientWithIngredient {recipeIngredient, ingredient = Nothing}

toRecipeRow :: RecipeRecipeIngredientJoinRow -> RecipeRow
toRecipeRow row = RecipeRow {id = row.recipeId, createdAt = row.recipeCreatedAt, updatedAt = row.recipeUpdatedAt, name = row.recipeName, description = row.recipeDescription}

toRecipeIngredientRow :: RecipeRecipeIngredientJoinRow -> Maybe RecipeIngredientRow
toRecipeIngredientRow row
  | Just rid <- row.recipeIngredientId,
    Just ingredientId <- row.recipeIngredientIngredientId,
    Just amount <- row.recipeIngredientAmount,
    Just unit <- row.recipeIngredientUnit =
      Just RecipeIngredientRow {id = rid, ingredientId = ingredientId, amount = amount, unit = unit, recipeId = row.recipeId}
  | otherwise = Nothing

nestRecipeRecipeIngredientIngredientRows :: [RecipeRecipeIngredientIngredientJoinRow] -> [RecipeWithIngredients]
nestRecipeRecipeIngredientIngredientRows =
  map recipeWithIngredientFromRecipeGroup . groupByKey (.recipeId)

recipeWithIngredientFromRecipeGroup :: [RecipeRecipeIngredientIngredientJoinRow] -> RecipeWithIngredients
recipeWithIngredientFromRecipeGroup rows@(firstRow : _) =
  RecipeWithIngredients
    { recipe = toRecipeRowFromIngredient firstRow,
      ingredients = mapMaybe recipeIngredientWithIngredientFromGroup $ groupByKey (.recipeIngredientId) rows
    }
recipeWithIngredientFromRecipeGroup [] =
  error "recipeWithIngredientFromRecipeGroup: empty group"

recipeIngredientWithIngredientFromGroup :: [RecipeRecipeIngredientIngredientJoinRow] -> Maybe RecipeIngredientWithIngredient
recipeIngredientWithIngredientFromGroup (firstRow : _)
  | Just _ <- firstRow.recipeIngredientId =
      Just
        RecipeIngredientWithIngredient
          { recipeIngredient = toRecipeIngredientRowFromIngredient firstRow,
            ingredient = toIngredientRow firstRow
          }
  | otherwise = Nothing
recipeIngredientWithIngredientFromGroup [] = Nothing

toRecipeRowFromIngredient :: RecipeRecipeIngredientIngredientJoinRow -> RecipeRow
toRecipeRowFromIngredient row = RecipeRow {id = row.recipeId, createdAt = row.recipeCreatedAt, updatedAt = row.recipeUpdatedAt, name = row.recipeName, description = row.recipeDescription}

toRecipeIngredientRowFromIngredient :: RecipeRecipeIngredientIngredientJoinRow -> RecipeIngredientRow
toRecipeIngredientRowFromIngredient row =
  RecipeIngredientRow
    { id = fromMaybe (error "toRecipeIngredientRowFromIngredient: missing id") row.recipeIngredientId,
      ingredientId = fromMaybe (error "toRecipeIngredientRowFromIngredient: missing ingredientId") row.recipeIngredientIngredientId,
      amount = fromMaybe (error "toRecipeIngredientRowFromIngredient: missing amount") row.recipeIngredientAmount,
      unit = fromMaybe (error "toRecipeIngredientRowFromIngredient: missing unit") row.recipeIngredientUnit,
      recipeId = row.recipeId
    }

toIngredientRow :: RecipeRecipeIngredientIngredientJoinRow -> Maybe IngredientRow
toIngredientRow row
  | Just iid <- row.ingredientId,
    Just createdAt <- row.ingredientCreatedAt,
    Just updatedAt <- row.ingredientUpdatedAt,
    Just name <- row.ingredientName =
      Just IngredientRow {id = iid, createdAt = createdAt, updatedAt = updatedAt, name = name}
  | otherwise = Nothing

instance {-# OVERLAPPING #-} ExecuteInclude RecipeTable RecipeInclude RecipeWithIngredients where
  executeInclude conn include modifier =
    case include.ingredients of
      Nothing -> do
        roots <- findManyConn @RecipeTable @RecipeRow conn modifier
        pure $ map (wrapRoot include) roots
      Just RecipeIngredientInclude {ingredient = False} -> do
        let chain = applyRootFilter buildRecipeRecipeIngredientJoin modifier
        flatRows <- JoinChain.runJoinChainConn @RecipeRecipeIngredientJoinRow conn chain
        pure $ nestRecipeRows flatRows
      Just RecipeIngredientInclude {ingredient = True} -> do
        let chain = applyRootFilter buildRecipeRecipeIngredientIngredientJoin modifier
        flatRows <- JoinChain.runJoinChainConn @RecipeRecipeIngredientIngredientJoinRow conn chain
        pure $ nestRecipeRecipeIngredientIngredientRows flatRows

