{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.TargetSpec
  ( targetSpec,
  )
where

import Data.List (nub, sort)
import qualified Data.Text as T
import ORM.Codegen.RecipeTarget (prodTarget)
import ORM.Codegen.Run (allOutputs, schemasForTargets)
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import ORM.Codegen.Spec.Widget (widgetSchema)
import ORM.Codegen.Target
  ( CodegenTarget,
    GenOutput (..),
    targetOutputs,
    testTarget,
  )
import Test.Hspec

allTargets :: [CodegenTarget]
allTargets = [testTarget, prodTarget]

targetSpec :: Spec
targetSpec =
  describe "ORM.Codegen.Target" $ do
    it "validates every schema referenced by a target" $ do
      schemasForTargets allTargets
        `shouldMatchList` [ widgetSchema,
                            shelfSchema,
                            recipeSchema
                          ]

    it "derives 36 outputs across all targets" $ do
      length (concatMap targetOutputs allTargets) `shouldBe` 36
      length (allOutputs allTargets) `shouldBe` 36

    it "derives expected output paths" $ do
      let paths = sort (nub (map outputPath (allOutputs allTargets)))
      paths
        `shouldBe` sort
          [ ".orm-gen/ORM/Client/Ingredient.hs",
            ".orm-gen/ORM/Client/Recipe.hs",
            ".orm-gen/ORM/Client/RecipeIngredient.hs",
            ".orm-gen/ORM/Schema/Ingredient.hs",
            ".orm-gen/ORM/Schema/Recipe.hs",
            ".orm-gen/ORM/Schema/RecipeInclude.hs",
            ".orm-gen/ORM/Schema/RecipeIngredient.hs",
            ".orm-gen/ORM/Schema/RecipeIngredientInclude.hs",
            ".orm-gen/ORM/Schema/Unit.hs",
            "test/ORM/Codegen/golden/Book.hs.golden",
            "test/ORM/Codegen/golden/BookInclude.hs.golden",
            "test/ORM/Codegen/golden/Chapter.hs.golden",
            "test/ORM/Codegen/golden/ChapterInclude.hs.golden",
            "test/ORM/Codegen/golden/Ingredient.hs.golden",
            "test/ORM/Codegen/golden/IngredientClient.hs.golden",
            "test/ORM/Codegen/golden/Recipe.hs.golden",
            "test/ORM/Codegen/golden/RecipeClient.hs.golden",
            "test/ORM/Codegen/golden/RecipeInclude.hs.golden",
            "test/ORM/Codegen/golden/RecipeIngredient.hs.golden",
            "test/ORM/Codegen/golden/RecipeIngredientClient.hs.golden",
            "test/ORM/Codegen/golden/RecipeIngredientInclude.hs.golden",
            "test/ORM/Codegen/golden/Section.hs.golden",
            "test/ORM/Codegen/golden/Shelf.hs.golden",
            "test/ORM/Codegen/golden/ShelfInclude.hs.golden",
            "test/ORM/Codegen/golden/Tag.hs.golden",
            "test/ORM/Codegen/golden/Unit.hs.golden",
            "test/ORM/Codegen/golden/Widget.hs.golden",
            "test/Schema/Book.hs",
            "test/Schema/BookInclude.hs",
            "test/Schema/Chapter.hs",
            "test/Schema/ChapterInclude.hs",
            "test/Schema/Section.hs",
            "test/Schema/Shelf.hs",
            "test/Schema/ShelfInclude.hs",
            "test/Schema/Tag.hs",
            "test/Schema/Widget.hs"
          ]

    it "keeps generated text byte-stable for golden outputs" $ do
      mapM_ assertGoldenStable goldenOutputPaths
  where
    goldenOutputPaths =
      map outputPath (filter isGoldenOutput (allOutputs allTargets))

    isGoldenOutput output =
      "test/ORM/Codegen/golden/" `T.isPrefixOf` T.pack (outputPath output)

    assertGoldenStable path = do
      expected <- readFile path
      let output =
            head
              [ out
                | out <- allOutputs allTargets,
                  outputPath out == path
              ]
          actual = T.unpack (outputText output)
      actual `shouldBe` expected
