{-# LANGUAGE OverloadedRecordDot #-}

module ORM.NestedWriteSpec
  ( nestedWriteSpec,
  )
where

import Data.List (find, sort)
import Data.Text (Text)
import Data.UUID (UUID)
import ORM (NullableValue (..), runDb)
import qualified ORM.Client.Ingredient as Ingredient
import qualified ORM.Client.Recipe as Recipe
import ORM.Db (DbPool)
import ORM.Schema.Ingredient (IngredientCreate (..), IngredientRow, IngredientTable)
import ORM.Schema.Recipe (RecipeTable)
import ORM.Schema.Unit (Unit (G, Ml))
import ORM.Where (eq)
import Support.Assert (assertRight)
import Support.TestDb (TestEnv (..), truncateTable)
import Test.Hspec (SpecWith, describe, it, shouldBe)

nestedWriteSpec :: SpecWith TestEnv
nestedWriteSpec =
  describe "nested writes" $ do
    it "create with Set inserts children" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      created <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G]))
          >>= assertRight
      map (.recipeIngredient.amount) created.ingredients `shouldBe` [100]

    it "create with Ops.create inserts children" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      created <-
        runDb
          pool
          ( Recipe.create
              Recipe.withIngredients
              Recipe.RecipeWriteCreate
                { root = recipeCreate "Pasta",
                  ingredients = Recipe.Ops (opsCreate [nested flour.id 100 G])
                }
          )
          >>= assertRight
      map (.recipeIngredient.amount) created.ingredients `shouldBe` [100]

    it "update Set replaces all children" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      salt <- insertIngredient pool "salt"
      created <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G]))
          >>= assertRight
      updated <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Set [nested salt.id 5 G]))
          )
          >>= assertRight
      map (\row -> (row.recipeIngredient.ingredientId, row.recipeIngredient.amount)) updated.ingredients
        `shouldBe` [(salt.id, 5)]

    it "update Ops.create adds without wiping" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      salt <- insertIngredient pool "salt"
      created <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G]))
          >>= assertRight
      updated <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Ops (opsCreate [nested salt.id 5 G])))
          )
          >>= assertRight
      length updated.ingredients `shouldBe` 2

    it "update with Nothing leaves children unchanged" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      created <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G]))
          >>= assertRight
      updated <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              Recipe.RecipeWriteUpdate {root = emptyRootUpdate, ingredients = Nothing}
          )
          >>= assertRight
      map (.recipeIngredient.amount) updated.ingredients `shouldBe` [100]

    it "update Ops.delete removes a child by id" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      salt <- insertIngredient pool "salt"
      created <-
        runDb
          pool
          (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G, nested salt.id 5 G]))
          >>= assertRight
      flourRow <- requireChild flour.id created.ingredients
      updated <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Ops (opsDelete [flourRow.recipeIngredient.id])))
          )
          >>= assertRight
      map (.recipeIngredient.ingredientId) updated.ingredients `shouldBe` [salt.id]

    it "update Ops.disconnect removes a child by id" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      salt <- insertIngredient pool "salt"
      created <-
        runDb
          pool
          (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G, nested salt.id 5 G]))
          >>= assertRight
      flourRow <- requireChild flour.id created.ingredients
      updated <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Ops (opsDisconnect [flourRow.recipeIngredient.id])))
          )
          >>= assertRight
      map (.recipeIngredient.ingredientId) updated.ingredients `shouldBe` [salt.id]

    it "update Ops.update changes amount on an existing child" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      created <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G]))
          >>= assertRight
      let riId = (head created.ingredients).recipeIngredient.id
      updated <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Ops (opsUpdate [(riId, nested flour.id 250 Ml)])))
          )
          >>= assertRight
      map (\row -> (row.recipeIngredient.amount, row.recipeIngredient.unit)) updated.ingredients
        `shouldBe` [(250, Ml)]

    it "upsert inserts then updates on the unique pair" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      created <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Pasta" []))
          >>= assertRight
      afterInsert <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Ops (opsUpsert [nested flour.id 10 G])))
          )
          >>= assertRight
      map (.recipeIngredient.amount) afterInsert.ingredients `shouldBe` [10]
      afterUpdate <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Ops (opsUpsert [nested flour.id 20 G])))
          )
          >>= assertRight
      map (.recipeIngredient.amount) afterUpdate.ingredients `shouldBe` [20]
      length afterUpdate.ingredients `shouldBe` 1

    it "createMany skips unique conflicts and inserts the rest" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      salt <- insertIngredient pool "salt"
      created <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Pasta" [nested flour.id 100 G]))
          >>= assertRight
      updated <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              created.recipe.id
              (writeUpdate (Recipe.Ops (opsCreateMany [nested flour.id 999 G, nested salt.id 1 G])))
          )
          >>= assertRight
      sort (map (\row -> (row.recipeIngredient.ingredientId, row.recipeIngredient.amount)) updated.ingredients)
        `shouldBe` sort [(flour.id, 100), (salt.id, 1)]

    it "connect re-parents an existing child row" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <- insertIngredient pool "flour"
      first <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "One" [nested flour.id 100 G]))
          >>= assertRight
      second <-
        runDb pool (Recipe.create Recipe.withIngredients (writeCreate "Two" []))
          >>= assertRight
      let riId = (head first.ingredients).recipeIngredient.id
      moved <-
        runDb
          pool
          ( Recipe.update
              Recipe.withIngredients
              second.recipe.id
              (writeUpdate (Recipe.Ops (opsConnect [riId])))
          )
          >>= assertRight
      leftover <-
        runDb
          pool
          ( Recipe.findUniqueOrFail
              Recipe.emptyQuery
                { Recipe.include_ = Recipe.withIngredients,
                  Recipe.where_ = Just (eq Recipe.recipeId first.recipe.id)
                }
          )
          >>= assertRight
      map (.recipeIngredient.id) moved.ingredients `shouldBe` [riId]
      leftover.ingredients `shouldBe` []

nested :: UUID -> Int -> Unit -> Recipe.RecipeIngredientNestedCreate
nested ingredientId amount unit =
  Recipe.RecipeIngredientNestedCreate {ingredientId, amount, unit}

opsCreate :: [Recipe.RecipeIngredientNestedCreate] -> Recipe.RecipeIngredientNestedOps
opsCreate items =
  Recipe.RecipeIngredientNestedOps
    { create = items,
      createMany = [],
      connect = [],
      disconnect = [],
      delete = [],
      update = [],
      upsert = []
    }

opsDelete :: [UUID] -> Recipe.RecipeIngredientNestedOps
opsDelete ids =
  Recipe.RecipeIngredientNestedOps
    { create = [],
      createMany = [],
      connect = [],
      disconnect = [],
      delete = ids,
      update = [],
      upsert = []
    }

opsDisconnect :: [UUID] -> Recipe.RecipeIngredientNestedOps
opsDisconnect ids =
  Recipe.RecipeIngredientNestedOps
    { create = [],
      createMany = [],
      connect = [],
      disconnect = ids,
      delete = [],
      update = [],
      upsert = []
    }

opsUpdate :: [(UUID, Recipe.RecipeIngredientNestedCreate)] -> Recipe.RecipeIngredientNestedOps
opsUpdate items =
  Recipe.RecipeIngredientNestedOps
    { create = [],
      createMany = [],
      connect = [],
      disconnect = [],
      delete = [],
      update = items,
      upsert = []
    }

opsUpsert :: [Recipe.RecipeIngredientNestedCreate] -> Recipe.RecipeIngredientNestedOps
opsUpsert items =
  Recipe.RecipeIngredientNestedOps
    { create = [],
      createMany = [],
      connect = [],
      disconnect = [],
      delete = [],
      update = [],
      upsert = items
    }

opsCreateMany :: [Recipe.RecipeIngredientNestedCreate] -> Recipe.RecipeIngredientNestedOps
opsCreateMany items =
  Recipe.RecipeIngredientNestedOps
    { create = [],
      createMany = items,
      connect = [],
      disconnect = [],
      delete = [],
      update = [],
      upsert = []
    }

opsConnect :: [UUID] -> Recipe.RecipeIngredientNestedOps
opsConnect ids =
  Recipe.RecipeIngredientNestedOps
    { create = [],
      createMany = [],
      connect = ids,
      disconnect = [],
      delete = [],
      update = [],
      upsert = []
    }

writeCreate :: Text -> [Recipe.RecipeIngredientNestedCreate] -> Recipe.RecipeWriteCreate
writeCreate name items =
  Recipe.RecipeWriteCreate
    { root = recipeCreate name,
      ingredients = Recipe.Set items
    }

writeUpdate :: Recipe.IngredientsWrite -> Recipe.RecipeWriteUpdate
writeUpdate ingredients =
  Recipe.RecipeWriteUpdate
    { root = emptyRootUpdate,
      ingredients = Just ingredients
    }

emptyRootUpdate :: Recipe.RecipeUpdate
emptyRootUpdate =
  Recipe.RecipeUpdate
    { name = Nothing,
      createdAt = Nothing,
      updatedAt = Nothing,
      description = Omit
    }

recipeCreate :: Text -> Recipe.RecipeCreate
recipeCreate name =
  Recipe.RecipeCreate
    { id = Nothing,
      createdAt = Nothing,
      updatedAt = Nothing,
      name,
      description = Omit
    }

insertIngredient :: DbPool -> Text -> IO IngredientRow
insertIngredient pool name =
  runDb
    pool
    ( Ingredient.create
        ( IngredientCreate
            { id = Nothing,
              createdAt = Nothing,
              updatedAt = Nothing,
              name
            }
        )
    )
    >>= assertRight

requireChild :: UUID -> [Recipe.RecipeIngredientWithIngredient] -> IO Recipe.RecipeIngredientWithIngredient
requireChild ingredientId rows =
  case find (\row -> row.recipeIngredient.ingredientId == ingredientId) rows of
    Just row -> pure row
    Nothing -> fail "expected nested recipe ingredient"

resetRecipes :: TestEnv -> IO ()
resetRecipes env = do
  truncateTable @RecipeTable env
  truncateTable @IngredientTable env
