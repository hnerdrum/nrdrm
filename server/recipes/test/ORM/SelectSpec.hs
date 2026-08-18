{-# LANGUAGE OverloadedRecordDot #-}

module ORM.SelectSpec
  ( selectSpec,
  )
where

import ORM (NullableValue (..), Picked (..), runDb)
import qualified ORM.Client.Ingredient as Ingredient
import qualified ORM.Client.Recipe as Recipe
import qualified ORM.Operations as Ops
import ORM.Query (selectColumns)
import ORM.Schema.Ingredient (IngredientCreate (..), IngredientSelect (..), IngredientTable)
import ORM.Schema.Recipe (RecipeSelect (..), RecipeTable, recipeName)
import ORM.Schema.Unit (Unit (G))
import ORM.Select (picked)
import ORM.Where (eq)
import qualified ORM.WidgetFixtures as WidgetFixtures
import Schema.Widget
  ( WidgetPicked (..),
    WidgetRow (..),
    WidgetSelect (..),
    WidgetTable,
    parseWidgetPicked,
    widgetSelectColumns,
  )
import Support.Assert (assertRight)
import Support.TestDb (TestEnv (..), truncateTable)
import Test.Hspec (SpecWith, describe, it, shouldBe)

selectSpec :: SpecWith TestEnv
selectSpec = do
  describe "ORM.Select columns" $ do
    it "always includes the primary key and only requested scalars" $ \_ ->
      widgetSelectColumns
        WidgetSelect
          { id = False,
            createdAt = False,
            updatedAt = False,
            name = True,
            description = True
          }
        `shouldBe` ["id", "name", "description"]

    it "maps False fields to Skipped" $ \_ -> do
      picked False ("secret" :: String) `shouldBe` Skipped
      picked True ("shown" :: String) `shouldBe` Picked "shown"

  describe "single-table select_" $ do
    it "loads only requested widget columns into WidgetPicked" $ \TestEnv {envPool = pool} -> do
      widget <- WidgetFixtures.insertWidget pool "alpha"
      let sel =
            WidgetSelect
              { id = False,
                createdAt = False,
                updatedAt = False,
                name = True,
                description = False
              }
      [row] <-
        runDb pool $
          Ops.findManyWith @WidgetTable
            (parseWidgetPicked sel)
            (selectColumns (widgetSelectColumns sel))
      let WidgetRow {id = widgetId} = widget
          WidgetPicked {id = rowId, name = rowName, description = rowDescription, createdAt = rowCreatedAt, updatedAt = rowUpdatedAt} = row
      rowId `shouldBe` widgetId
      rowName `shouldBe` Picked "alpha"
      rowDescription `shouldBe` Skipped
      rowCreatedAt `shouldBe` Skipped
      rowUpdatedAt `shouldBe` Skipped

    it "keeps IngredientRow when select_ is OmitSelect" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      created <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "salt"}))
          >>= assertRight
      rows <- runDb pool (Ingredient.findMany Ingredient.emptyQuery)
      map (.name) rows `shouldBe` ["salt"]
      map (.id) rows `shouldBe` [created.id]

    it "returns IngredientPicked when select_ is set" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      created <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "pepper"}))
          >>= assertRight
      let sel =
            IngredientSelect
              { id = False,
                createdAt = False,
                updatedAt = False,
                name = True
              }
          query :: Ingredient.IngredientQuery IngredientSelect
          query =
            Ingredient.IngredientQuery
              { select_ = sel,
                where_ = Nothing,
                orderBy_ = Nothing,
                limit_ = Nothing,
                offset_ = Nothing
              }
      [row] <- runDb pool (Ingredient.findMany query)
      row.id `shouldBe` created.id
      row.name `shouldBe` Picked "pepper"
      row.createdAt `shouldBe` Skipped
      row.updatedAt `shouldBe` Skipped

  describe "select_ + include" $ do
    it "projects recipe scalars and keeps nested ingredients" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      ingredient <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "flour"}))
          >>= assertRight
      created <-
        runDb
          pool
          ( Recipe.create
              Recipe.withIngredients
              Recipe.RecipeWriteCreate
                { root =
                    Recipe.RecipeCreate
                      { id = Nothing,
                        createdAt = Nothing,
                        updatedAt = Nothing,
                        name = "Pasta",
                        description = Value "fresh"
                      },
                  ingredients =
                    [ Recipe.RecipeIngredientNestedCreate
                        { ingredientId = ingredient.id,
                          amount = 100,
                          unit = G
                        }
                    ]
                }
          )
          >>= assertRight
      let sel =
            RecipeSelect
              { id = False,
                createdAt = False,
                updatedAt = False,
                name = True,
                description = True
              }
          query :: Recipe.RecipeQuery Recipe.WithIngredients RecipeSelect
          query =
            Recipe.RecipeQuery
              { select_ = sel,
                where_ = Just (eq recipeName "Pasta"),
                orderBy_ = Nothing,
                limit_ = Nothing,
                offset_ = Nothing
              }
      [row] <- runDb pool (Recipe.findMany query)
      row.recipe.id `shouldBe` created.recipe.id
      row.recipe.name `shouldBe` Picked "Pasta"
      row.recipe.description `shouldBe` Picked (Just "fresh")
      row.recipe.createdAt `shouldBe` Skipped
      length row.ingredients `shouldBe` 1
      (head row.ingredients).recipeIngredient.amount `shouldBe` 100

resetRecipes :: TestEnv -> IO ()
resetRecipes env = do
  truncateTable @RecipeTable env
  truncateTable @IngredientTable env
