{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitClientSpec
  ( emitClientSpec,
  )
where

import Data.List (find)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import ORM.Codegen.Emit.Client
  ( emitIncludeReadClientModule,
    emitSimpleClientModule,
    emitWriteClientModule,
  )
import ORM.Codegen.IR
  ( Model (..),
    Schema (..),
    modelName,
    schemaIncludes,
    schemaModels,
  )
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import Test.Hspec

emitClientSpec :: Spec
emitClientSpec =
  describe "ORM.Codegen.Emit.Client" $ do
    it "emits Ingredient Client matching the golden file" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/IngredientClient.hs.golden"
      let actual = emitSimpleClientModule "ORM.Client.Ingredient" ingredientModel
      T.strip actual `shouldBe` T.strip expected

    it "emits Recipe Client matching the golden file" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/RecipeClient.hs.golden"
      let incl = head (schemaIncludes recipeSchema)
          actual = emitWriteClientModule "ORM.Client.Recipe" recipeSchema incl
      T.strip actual `shouldBe` T.strip expected

    it "emits Shelf read Client with include helpers" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/ShelfReadClient.hs.golden"
      let incl = head (schemaIncludes shelfSchema)
          actual = emitIncludeReadClientModule "Schema.Client.Shelf" shelfSchema incl
      T.strip actual `shouldBe` T.strip expected

ingredientModel :: Model
ingredientModel =
  case find ((== "Ingredient") . modelName) (schemaModels recipeSchema) of
    Just m -> m
    Nothing -> error "ingredientModel: Ingredient missing"
