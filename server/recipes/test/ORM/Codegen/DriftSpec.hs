{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.DriftSpec
  ( driftSpec,
    driftDbSpec,
  )
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import ORM.Codegen.Drift
import ORM.Codegen.Introspect (introspectCatalog)
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import ORM.Codegen.Spec.Widget (widgetSchema)
import ORM.Db (withConn)
import Support.TestDb (TestEnv (..))
import Test.Hspec

driftSpec :: Spec
driftSpec =
  describe "ORM.Codegen.Drift" $ do
    it "accepts an IR that matches the catalog" $
      checkSchema widgetSchema (widgetCatalog False) `shouldBe` []

    it "reports a missing table" $
      checkSchema widgetSchema emptyCatalog
        `shouldBe` [DriftMissingTable "Widget" "test_widget"]

    it "reports nullability drift" $
      checkSchema widgetSchema (widgetCatalog True)
        `shouldBe` [DriftNullability "test_widget" "name" False True]

    it "reports a missing unique from the IR" $
      checkSchema recipeSchema recipeCatalogWithoutUnique
        `shouldBe` [DriftMissingUnique "recipe_ingredient" ["ingredient_id", "recipe_id"]]

    it "reports a database unique that is not in the IR" $
      checkSchema widgetSchema widgetCatalogWithUnique
        `shouldBe` [DriftUnexpectedUnique "test_widget" ["name"]]

    it "reports enum label drift" $
      checkSchema recipeSchema recipeCatalogWrongEnum
        `shouldBe` [DriftEnumLabels "Unit" ["g", "ml", "qty", "tbsp", "tsp"] ["g", "ml"]]

driftDbSpec :: SpecWith TestEnv
driftDbSpec =
  describe "ORM.Codegen.Drift against Postgres" $ do
    it "matches widget, shelf, and recipe IR to the test database" $ \TestEnv {envPool = pool} -> do
      catalog <- withConn pool introspectCatalog
      checkSchema widgetSchema catalog `shouldBe` []
      checkSchema shelfSchema catalog `shouldBe` []
      checkSchema recipeSchema catalog `shouldBe` []

widgetCatalog :: Bool -> DbCatalog
widgetCatalog nameNullable =
  emptyCatalog
    { dbTables =
        Map.singleton
          "test_widget"
          DbTable
            { dbTableName = "test_widget",
              dbColumns =
                Map.fromList
                  [ col "id" "uuid" False,
                    col "created_at" "timestamptz" False,
                    col "updated_at" "timestamptz" False,
                    col "name" "text" nameNullable,
                    col "description" "text" True
                  ],
              dbPrimaryKey = ["id"],
              dbUniques = []
            }
    }

widgetCatalogWithUnique :: DbCatalog
widgetCatalogWithUnique =
  let base = widgetCatalog False
      table = dbTables base Map.! "test_widget"
   in base {dbTables = Map.singleton "test_widget" table {dbUniques = [Set.singleton "name"]}}

recipeCatalogWithoutUnique :: DbCatalog
recipeCatalogWithoutUnique =
  emptyCatalog
    { dbTables = recipeTables,
      dbEnums = Map.singleton "unit" ["g", "ml", "tsp", "tbsp", "qty"]
    }

recipeCatalogWrongEnum :: DbCatalog
recipeCatalogWrongEnum =
  (recipeCatalogWithoutUnique)
    { dbEnums = Map.singleton "unit" ["g", "ml"],
      dbTables =
        Map.insert
          "recipe_ingredient"
          ( (recipeTables Map.! "recipe_ingredient")
              { dbUniques = [Set.fromList ["recipe_id", "ingredient_id"]]
              }
          )
          recipeTables
    }

recipeTables :: Map Text DbTable
recipeTables =
  Map.fromList
    [ ( "recipe",
        DbTable
          { dbTableName = "recipe",
            dbColumns =
              Map.fromList
                [ col "id" "uuid" False,
                  col "created_at" "timestamptz" False,
                  col "updated_at" "timestamptz" False,
                  col "name" "text" False,
                  col "description" "text" True
                ],
            dbPrimaryKey = ["id"],
            dbUniques = []
          }
      ),
      ( "ingredient",
        DbTable
          { dbTableName = "ingredient",
            dbColumns =
              Map.fromList
                [ col "id" "uuid" False,
                  col "created_at" "timestamptz" False,
                  col "updated_at" "timestamptz" False,
                  col "name" "text" False
                ],
            dbPrimaryKey = ["id"],
            dbUniques = []
          }
      ),
      ( "recipe_ingredient",
        DbTable
          { dbTableName = "recipe_ingredient",
            dbColumns =
              Map.fromList
                [ col "id" "uuid" False,
                  col "recipe_id" "uuid" False,
                  col "ingredient_id" "uuid" False,
                  col "amount" "int" False,
                  col "unit" "enum:unit" False
                ],
            dbPrimaryKey = ["id"],
            dbUniques = []
          }
      )
    ]

col :: Text -> Text -> Bool -> (Text, DbColumn)
col name ty isNullable =
  (name, DbColumn {dbColName = name, dbColType = ty, dbColNullable = isNullable})
