module Main (main) where

import ORM.Codegen.EmitClientSpec (emitClientSpec)
import ORM.Codegen.EmitFlatRowSpec (emitFlatRowSpec)
import ORM.Codegen.EmitIncludeSpec (emitIncludeSpec)
import ORM.Codegen.EmitSpec (emitSpec)
import ORM.Codegen.ValidateSpec (validateSpec)
import ORM.IncludeSpec (includeSpec)
import ORM.JoinSpec (joinSpec)
import ORM.OperationsSpec (operationsSpec)
import Support.TestDb (withTestDb)
import Test.Hspec

main :: IO ()
main = hspec $ do
  validateSpec
  emitSpec
  emitFlatRowSpec
  emitIncludeSpec
  emitClientSpec
  withTestDb $ operationsSpec >> joinSpec >> includeSpec
