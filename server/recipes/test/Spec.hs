module Main (main) where

import Domain.RecipeSpec (recipeSpec)
import ORM.Codegen.TargetSpec (targetSpec)
import ORM.NestedWriteSpec (nestedWriteSpec)
import Support.TestDb (withTestDb)
import Test.Hspec

main :: IO ()
main = hspec $ do
  recipeSpec
  targetSpec
  withTestDb nestedWriteSpec
