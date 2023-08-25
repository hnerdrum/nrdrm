{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Recipe
    (
      Recipe(..)
    , getAllRecipes
    , getRecipe
    , RecipeDbError(..)
    ) where

import Data.Aeson
import Data.Aeson.TH
import qualified Data.List.NonEmpty as NE
import Data.Text hiding (map, head, null, filter, length)
import Data.Time
import Data.UUID hiding (null)
import qualified Data.Map as Map
import Data.Pool (Pool, withResource)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow
import Domain.Ingredient

data Recipe = Recipe
  { id          :: UUID
  , createdAt   :: UTCTime
  , updatedAt   :: UTCTime
  , name        :: Text
  , description :: Text
  , ingredients :: [Ingredient]
  } deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

data DbRecipeIngredient = DbRecipeIngredient
  { dbRecipeId :: UUID
  , dbRecipeCreatedAt :: UTCTime
  , dbRecipeUpdatedAt :: UTCTime
  , dbRecipeName      :: Text
  , dbRecipeDescription :: Text
  , dbIngredientId :: UUID
  , dbIngredientCreatedAt :: UTCTime
  , dbIngredientUpdatedAt :: UTCTime
  , dbIngredientName :: Text
  , dbIngredientAmount :: Int
  , dbIngredientUnit :: Unit
  } deriving (Show)

instance FromRow DbRecipeIngredient where
  fromRow = DbRecipeIngredient <$> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field

data RecipeDbError = RecipeNotFound | MultipleRecipesFound
  deriving (Eq, Show)

getAllRecipes :: Pool PGSimple.Connection -> IO [Recipe]
getAllRecipes pool =
  withResource pool $ \conn -> do
    dbRecipeIngredients <- PGSimple.query_ conn "SELECT r.id, r.created_at, r.updated_at, r.name, r.description, i.id, i.created_at , i.updated_at, i.name, ri.amount, ri.unit FROM recipe r JOIN recipe_ingredient ri ON r.id = ri.recipe_id JOIN ingredient i ON i.id = ri.ingredient_id"
    return $ mapDbRecipeIngredients dbRecipeIngredients

getRecipe :: Pool PGSimple.Connection -> UUID -> IO (Either RecipeDbError Recipe)
getRecipe pool recipeId =
  withResource pool $ \conn -> do
    dbRecipeIngredients <- PGSimple.query conn ("SELECT r.id, r.created_at, r.updated_at, r.name, r.description, i.id, i.created_at , i.updated_at, i.name, ri.amount, ri.unit FROM recipe r JOIN recipe_ingredient ri ON r.id = ri.recipe_id JOIN ingredient i ON i.id = ri.ingredient_id WHERE r.id = ?") (PGSimple.Only recipeId)
    return $ fromDbRecipeIngredients dbRecipeIngredients

mapDbRecipeIngredients :: [DbRecipeIngredient] -> [Recipe]
mapDbRecipeIngredients dbRecipeIngredients =
  map toRecipe recipeGroups
  where
    groupedRecipeIngredients = Map.fromListWith (++) [(dbRecipeId ri, [ri]) | ri <- dbRecipeIngredients]
    recipeGroups = map NE.fromList $ filter (not . null) $ Map.elems groupedRecipeIngredients

fromDbRecipeIngredients :: [DbRecipeIngredient] -> Either RecipeDbError Recipe
fromDbRecipeIngredients dbRecipeIngredients
  | length recipeGroups == 0 = Left RecipeNotFound
  | length recipeGroups == 1 = Right $ toRecipe $ head recipeGroups
  | otherwise                = Left MultipleRecipesFound
  where
    groupedRecipeIngredients = Map.fromListWith (++) [(dbRecipeId ri, [ri]) | ri <- dbRecipeIngredients]
    recipeGroups = map NE.fromList $ filter (not . null) $ Map.elems groupedRecipeIngredients

toRecipe :: NE.NonEmpty DbRecipeIngredient -> Recipe
toRecipe dbRIs =
  Recipe
    { id = dbRecipeId (NE.head dbRIs)
    , createdAt = dbRecipeCreatedAt (NE.head dbRIs)
    , updatedAt = dbRecipeUpdatedAt (NE.head dbRIs)
    , name = dbRecipeName (NE.head dbRIs)
    , description = dbRecipeDescription (NE.head dbRIs)
    , ingredients = NE.toList $ NE.map toIngredient dbRIs
    }

toIngredient :: DbRecipeIngredient -> Ingredient
toIngredient dbRI =
  Ingredient
    { id = dbIngredientId dbRI
    , createdAt = dbIngredientCreatedAt dbRI
    , updatedAt = dbIngredientUpdatedAt dbRI
    , name = dbIngredientName dbRI
    , amount = dbIngredientAmount dbRI
    , unit = dbIngredientUnit dbRI
    }