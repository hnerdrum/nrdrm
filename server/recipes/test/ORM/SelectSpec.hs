{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}

module ORM.SelectSpec
  ( selectSpec,
  )
where

import ORM (NullableValue (..), ORMError (..), Picked (..), runDb)
import qualified ORM.Client.Ingredient as Ingredient
import qualified ORM.Client.Recipe as Recipe
import qualified ORM.Operations as Ops
import ORM.Query (selectColumns)
import ORM.Schema.Ingredient (IngredientCreate (..), IngredientSelect (..), IngredientTable, ingredientName)
import ORM.Schema.Recipe (RecipeSelect (..), RecipeTable, recipeId, recipeName)
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
import Test.Hspec (SpecWith, describe, it, shouldBe, shouldSatisfy)

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

    it "findUnique looks up by where_ on the query record" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      created <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "thyme"}))
          >>= assertRight
      found <-
        runDb
          pool
          ( Ingredient.findUnique
              Ingredient.emptyQuery {Ingredient.where_ = Just (eq Ingredient.ingredientId created.id)}
          )
      found `shouldBe` Right (Just created)

    it "findUnique rejects a where_ that is not a unique key" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      _ <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "sage"}))
          >>= assertRight
      found <-
        runDb
          pool
          ( Ingredient.findUnique
              Ingredient.emptyQuery {Ingredient.where_ = Just (eq ingredientName "sage")}
          )
      found
        `shouldSatisfy` ( \case
                            Left (InvalidUniqueInput _) -> True
                            _ -> False
                        )

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
                    Recipe.Set
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
              { include_ = Recipe.withIngredients,
                select_ = sel,
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

    it "projects recipe scalars with noInclude" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      _ <-
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
                        name = "Broth",
                        description = Value "clear"
                      },
                  ingredients = Recipe.Set []
                }
          )
          >>= assertRight
      let sel =
            RecipeSelect
              { id = False,
                createdAt = False,
                updatedAt = False,
                name = True,
                description = False
              }
          query :: Recipe.RecipeQuery Recipe.NoInclude RecipeSelect
          query =
            Recipe.RecipeQuery
              { include_ = Recipe.noInclude,
                select_ = sel,
                where_ = Just (eq recipeName "Broth"),
                orderBy_ = Nothing,
                limit_ = Nothing,
                offset_ = Nothing
              }
      [row] <- runDb pool (Recipe.findMany query)
      row.name `shouldBe` Picked "Broth"
      row.description `shouldBe` Skipped

    it "findUnique applies include from the query record" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      ingredient <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "egg"}))
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
                        name = "Omelette",
                        description = Value "simple"
                      },
                  ingredients =
                    Recipe.Set
                      [ Recipe.RecipeIngredientNestedCreate
                          { ingredientId = ingredient.id,
                            amount = 2,
                            unit = G
                          }
                      ]
                }
          )
          >>= assertRight
      found <-
        runDb
          pool
          ( Recipe.findUnique
              Recipe.emptyQuery
                { Recipe.include_ = Recipe.withIngredients,
                  Recipe.where_ = Just (eq recipeId created.recipe.id)
                }
          )
          >>= assertRight
      fmap (.recipe.name) found `shouldBe` Just "Omelette"
      fmap (length . (.ingredients)) found `shouldBe` Just 1

    it "findMany emptyQuery returns RecipeRow without include_" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
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
                        name = "Toast",
                        description = Omit
                      },
                  ingredients = Recipe.Set []
                }
          )
          >>= assertRight
      rows <- runDb pool (Recipe.findMany Recipe.emptyQuery)
      map (.name) rows `shouldBe` ["Toast"]
      map (.id) rows `shouldBe` [created.recipe.id]
      found <-
        runDb
          pool
          ( Recipe.findUnique
              Recipe.emptyQuery {Recipe.where_ = Just (eq recipeId created.recipe.id)}
          )
          >>= assertRight
      fmap (.name) found `shouldBe` Just "Toast"

    it "findMany uses ingredients ingredient as the full Recipe Include" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "flour"}))
          >>= assertRight
      created <-
        runDb
          pool
          ( Recipe.create
              (Recipe.ingredients Recipe.ingredient)
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
                    Recipe.Set
                      [ Recipe.RecipeIngredientNestedCreate
                          { ingredientId = flour.id,
                            amount = 100,
                            unit = G
                          }
                      ]
                }
          )
          >>= assertRight
      rows <-
        runDb
          pool
          ( Recipe.findMany
              Recipe.emptyQuery {Recipe.include_ = Recipe.ingredients Recipe.ingredient}
          )
      map (.recipe.name) rows `shouldBe` ["Pasta"]
      map (.recipe.id) rows `shouldBe` [created.recipe.id]
      length (head rows).ingredients `shouldBe` 1
      (head (head rows).ingredients).ingredient `shouldBe` Just flour

    it "findUnique and findUniqueOrFail resolve ingredients ingredient to RecipeWithIngredients" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      egg <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "egg"}))
          >>= assertRight
      created <-
        runDb
          pool
          ( Recipe.create
              (Recipe.ingredients Recipe.ingredient)
              Recipe.RecipeWriteCreate
                { root =
                    Recipe.RecipeCreate
                      { id = Nothing,
                        createdAt = Nothing,
                        updatedAt = Nothing,
                        name = "Omelette",
                        description = Value "simple"
                      },
                  ingredients =
                    Recipe.Set
                      [ Recipe.RecipeIngredientNestedCreate
                          { ingredientId = egg.id,
                            amount = 2,
                            unit = G
                          }
                      ]
                }
          )
          >>= assertRight
      let query =
            Recipe.emptyQuery
              { Recipe.include_ = Recipe.ingredients Recipe.ingredient,
                Recipe.where_ = Just (eq recipeId created.recipe.id)
              }
      found <- runDb pool (Recipe.findUnique query) >>= assertRight
      fmap (.recipe.name) found `shouldBe` Just "Omelette"
      fmap (length . (.ingredients)) found `shouldBe` Just 1
      required <- runDb pool (Recipe.findUniqueOrFail query) >>= assertRight
      required.recipe.name `shouldBe` "Omelette"
      length required.ingredients `shouldBe` 1

    it "projects recipe scalars with ingredients ingredient on include_" $ \env@TestEnv {envPool = pool} -> do
      resetRecipes env
      flour <-
        runDb pool (Ingredient.create (IngredientCreate {id = Nothing, createdAt = Nothing, updatedAt = Nothing, name = "flour"}))
          >>= assertRight
      created <-
        runDb
          pool
          ( Recipe.create
              (Recipe.ingredients Recipe.ingredient)
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
                    Recipe.Set
                      [ Recipe.RecipeIngredientNestedCreate
                          { ingredientId = flour.id,
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
          query =
            Recipe.emptyQuery
              { Recipe.include_ = Recipe.ingredients Recipe.ingredient,
                Recipe.select_ = sel,
                Recipe.where_ = Just (eq recipeName "Pasta")
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
