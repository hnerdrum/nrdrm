module Main (main) where

import ORM.Codegen.ValidateSpec (validateSpec)
import ORM.IncludeSpec (includeSpec)
import ORM.JoinSpec (joinSpec)
import ORM.OperationsSpec (operationsSpec)
import Support.TestDb (withTestDb)
import Test.Hspec

main :: IO ()
main = hspec $ do
  validateSpec
  withTestDb $ operationsSpec >> joinSpec >> includeSpec
