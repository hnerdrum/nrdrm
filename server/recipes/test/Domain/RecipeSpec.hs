{-# LANGUAGE OverloadedStrings #-}

module Domain.RecipeSpec
  ( recipeSpec,
  )
where

import Data.Aeson (eitherDecode)
import Data.Either (isLeft)
import Data.Maybe (fromMaybe)
import Domain.Recipe (CreateRecipeIngredientInput (..), UpdateRecipeInput (..))
import Domain.Unit (Unit (..))
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe, shouldSatisfy)

recipeSpec :: Spec
recipeSpec =
  describe "Domain.Recipe JSON" $ do
    it "requires amount and unit on every update ingredient" $ do
      let missingAmount =
            "{\"ingredients\":[{\"id\":\"00000000-0000-0000-0000-000000000000\",\"unit\":\"g\"}]}"
          missingUnit =
            "{\"ingredients\":[{\"id\":\"00000000-0000-0000-0000-000000000000\",\"amount\":100}]}"
      (eitherDecode missingAmount :: Either String UpdateRecipeInput) `shouldSatisfy` isLeft
      (eitherDecode missingUnit :: Either String UpdateRecipeInput) `shouldSatisfy` isLeft

    it "keeps every update ingredient when amount and unit are present" $ do
      let json =
            "{\"ingredients\":[{\"id\":\"00000000-0000-0000-0000-000000000000\",\"amount\":100,\"unit\":\"g\"}]}"
      case eitherDecode json :: Either String UpdateRecipeInput of
        Right input -> do
          let dbIngredients = fromMaybe [] input.ingredients
          map (.amount) dbIngredients `shouldBe` [100]
          map (.unit) dbIngredients `shouldBe` [G]
        Left err -> expectationFailure err
