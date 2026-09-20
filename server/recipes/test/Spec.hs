module Main (main) where

import Domain.RecipeSpec (recipeSpec)
import Test.Hspec

main :: IO ()
main = hspec recipeSpec
