{-# LANGUAGE OverloadedRecordDot #-}

module Domain.Recipe
  ( Recipe (..),
    CreateRecipeInput (..),
    CreateRecipeIngredientInput (..),
    UpdateRecipeInput (..),
    getAllRecipes,
    getRecipe,
    createRecipe,
    updateRecipe,
    deleteRecipe,
  )
where

import Control.Monad (void)
import Data.Aeson (FromJSON (parseJSON), object, withObject, (.:), (.:?))
import Data.Aeson.TH (defaultOptions, deriveJSON)
import Data.Bifunctor (bimap)
import Data.Text (Text)
import Data.UUID (UUID)
import Domain.Errors (AppError (..), DomainError (..))
import Domain.Ingredient (RecipeIngredient (..))
import Domain.Unit (Unit (..), fromDbUnit, toDbUnit)
import Poppy (DatabaseErrorInfo (..), Db, Load, NullableValue (..), ORMError (..), load, loadWith)
import qualified Schema.Client.Recipe as Recipe
import Schema.Include.Recipe (RecipeInclude (..), RecipeWith (..))
import Schema.Include.RecipeIngredient (RecipeIngredientInclude (..), RecipeIngredientWith (..))
import Schema.Ingredient (IngredientRow (..), IngredientTable)
import Schema.Recipe (RecipeRow (..))
import Schema.RecipeIngredient (RecipeIngredientRow (..), RecipeIngredientTable)

data CreateRecipeInput = CreateRecipeInput
  { name :: Text,
    description :: Text,
    ingredients :: [CreateRecipeIngredientInput]
  }
  deriving (Show)

instance FromJSON CreateRecipeInput where
  parseJSON = withObject "CreateRecipeInput" $ \obj -> do
    nameValue <- obj .: "name"
    descriptionValue <- obj .: "description"
    ingredientsValue <- obj .: "ingredients"
    return $
      CreateRecipeInput
        { name = nameValue,
          description = descriptionValue,
          ingredients = ingredientsValue
        }

data UpdateRecipeInput = UpdateRecipeInput
  { name :: Maybe Text,
    description :: Maybe Text,
    ingredients :: Maybe [CreateRecipeIngredientInput]
  }
  deriving (Show)

instance FromJSON UpdateRecipeInput where
  parseJSON = withObject "UpdateRecipeInput" $ \obj -> do
    nameValue <- obj .:? "name"
    descriptionValue <- obj .:? "description"
    ingredientsValue <- obj .:? "ingredients"
    return $
      UpdateRecipeInput
        { name = nameValue,
          description = descriptionValue,
          ingredients = ingredientsValue
        }

data CreateRecipeIngredientInput = CreateRecipeIngredientInput
  { id :: UUID,
    amount :: Int,
    unit :: Unit
  }
  deriving (Show)

instance FromJSON CreateRecipeIngredientInput where
  parseJSON = withObject "CreateRecipeIngredientInput" $ \obj -> do
    ingredientIdValue <- obj .: "id"
    amountValue <- obj .: "amount"
    unitValue <- obj .: "unit"
    return $
      CreateRecipeIngredientInput
        { id = ingredientIdValue,
          amount = amountValue,
          unit = unitValue
        }

data Recipe = Recipe
  { id :: UUID,
    name :: Text,
    description :: Maybe Text,
    ingredients :: [RecipeIngredient]
  }
  deriving (Show)

$(deriveJSON defaultOptions ''Recipe)

getAllRecipes :: Db [Recipe]
getAllRecipes =
  map fromRecipeWith
    <$> Recipe.findMany Recipe.emptyQuery {Recipe.include_ = ingredientsInclude}

getRecipe :: UUID -> Db (Either AppError Recipe)
getRecipe recipeId =
  bimap fromRecipeError fromRecipeWith
    <$> Recipe.findUniqueOrFail
      (Recipe.uniqueQuery (Recipe.ById recipeId)) {Recipe.include_ = ingredientsInclude}

createRecipe :: CreateRecipeInput -> Db (Either AppError Recipe)
createRecipe input = do
  created <- Recipe.create (toRecipeCreate input)
  case created of
    Left err -> pure (Left (fromRecipeError err))
    Right row -> getRecipe row.id

updateRecipe :: UUID -> UpdateRecipeInput -> Db (Either AppError Recipe)
updateRecipe recipeId input = do
  updated <- Recipe.update (Recipe.ById recipeId) (toRecipeUpdate input)
  case updated of
    Left err -> pure (Left (fromRecipeError err))
    Right _row -> getRecipe recipeId

toRecipeCreate :: CreateRecipeInput -> Recipe.RecipeCreate
toRecipeCreate input =
  Recipe.RecipeCreate
    { id = Nothing,
      createdAt = Nothing,
      updatedAt = Nothing,
      name = input.name,
      description = Value input.description,
      ingredients = map toRecipeIngredientNestedCreate input.ingredients
    }

toRecipeUpdate :: UpdateRecipeInput -> Recipe.RecipeUpdate
toRecipeUpdate input =
  Recipe.RecipeUpdate
    { name = input.name,
      createdAt = Nothing,
      updatedAt = Nothing,
      description = maybe Omit Value input.description,
      ingredients =
        fmap
          ( \items ->
              Recipe.emptyIngredientsUpdate
                { Recipe.replaceWith = Just (map toRecipeIngredientNestedCreate items)
                }
          )
          input.ingredients
    }

toRecipeIngredientNestedCreate :: CreateRecipeIngredientInput -> Recipe.RecipeIngredientNestedCreate
toRecipeIngredientNestedCreate input =
  Recipe.CreateRecipeIngredient
    { id = Nothing,
      ingredientId = input.id,
      amount = input.amount,
      unit = toDbUnit input.unit
    }

deleteRecipe :: UUID -> Db ()
deleteRecipe recipeId = void (Recipe.delete (Recipe.ById recipeId))

ingredientsInclude ::
  RecipeInclude (Load RecipeIngredientTable (RecipeIngredientInclude (Load IngredientTable ())))
ingredientsInclude =
  RecipeInclude {ingredients = loadWith RecipeIngredientInclude {ingredient = load}}

fromRecipeError :: ORMError -> AppError
fromRecipeError err =
  case err of
    RecordNotFound message -> AppError NotFoundError message (object [])
    MultipleRecordsFound message -> AppError MultipleEntitiesError message (object [])
    UniqueViolation message -> AppError ConflictError message (object [])
    ForeignKeyViolation message -> AppError ConflictError message (object [])
    NotNullViolation message -> AppError ConflictError message (object [])
    EmptyWhere message -> AppError InternalError message (object [])
    DatabaseError DatabaseErrorInfo {message} -> AppError InternalError message (object [])
    DriverError _ message -> AppError InternalError message (object [])
    UnsupportedIncludeModifier message -> AppError InternalError message (object [])

type LoadedRecipe =
  RecipeWith (Load RecipeIngredientTable (RecipeIngredientInclude (Load IngredientTable ())))

type LoadedRecipeIngredient =
  RecipeIngredientWith (Load IngredientTable ())

fromRecipeWith :: LoadedRecipe -> Recipe
fromRecipeWith (RecipeWith RecipeRow {id = rid, name = rname, description = rdesc} ingredients) =
  Recipe
    { id = rid,
      name = rname,
      description = rdesc,
      ingredients = map fromDbRecipeIngredient ingredients
    }

fromDbRecipeIngredient :: LoadedRecipeIngredient -> RecipeIngredient
fromDbRecipeIngredient
  ( RecipeIngredientWith
      RecipeIngredientRow {amount, unit}
      IngredientRow {id = iid, name = iname}
    ) =
    RecipeIngredient
      { id = iid,
        name = iname,
        amount,
        unit = fromDbUnit unit
      }
