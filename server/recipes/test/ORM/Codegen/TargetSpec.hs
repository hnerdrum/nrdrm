{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.TargetSpec
  ( targetSpec,
  )
where

import Data.List (nub, sort)
import qualified Data.Text as T
import ORM.Codegen.RecipeTarget (prodTarget)
import ORM.Codegen.Spec.Recipe (recipeSchema)
import Poppy.Codegen.Run (allOutputs, schemasForTargets)
import Poppy.Codegen.Target
  ( CodegenTarget,
    GenOutput (..),
    targetOutputs,
  )
import Test.Hspec

allTargets :: [CodegenTarget]
allTargets = [prodTarget]

targetSpec :: Spec
targetSpec =
  describe "ORM.Codegen.Target" $ do
    it "validates the production schema" $ do
      schemasForTargets allTargets `shouldMatchList` [recipeSchema]

    it "derives 18 outputs for prodTarget" $ do
      length (concatMap targetOutputs allTargets) `shouldBe` 18
      length (allOutputs allTargets) `shouldBe` 18

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
            "test/Poppy/Codegen/golden/Ingredient.hs.golden",
            "test/Poppy/Codegen/golden/IngredientClient.hs.golden",
            "test/Poppy/Codegen/golden/Recipe.hs.golden",
            "test/Poppy/Codegen/golden/RecipeClient.hs.golden",
            "test/Poppy/Codegen/golden/RecipeInclude.hs.golden",
            "test/Poppy/Codegen/golden/RecipeIngredient.hs.golden",
            "test/Poppy/Codegen/golden/RecipeIngredientClient.hs.golden",
            "test/Poppy/Codegen/golden/RecipeIngredientInclude.hs.golden",
            "test/Poppy/Codegen/golden/Unit.hs.golden"
          ]

    it "keeps generated text byte-stable for golden outputs" $ do
      mapM_ assertGoldenStable goldenOutputPaths
  where
    goldenOutputPaths =
      map outputPath (filter isGoldenOutput (allOutputs allTargets))

    isGoldenOutput output =
      "test/Poppy/Codegen/golden/" `T.isPrefixOf` T.pack (outputPath output)

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
