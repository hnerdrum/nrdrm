module Main (main) where

import ORM.Codegen.EmitClientSpec (emitClientSpec)
import ORM.Codegen.EmitFlatRowSpec (emitFlatRowSpec)
import ORM.Codegen.EmitIncludeSpec (emitIncludeSpec)
import ORM.Codegen.EmitSpec (emitSpec)
import ORM.Codegen.IncludePathSpec (fourLevelPathSpec, includePathSpec)
import ORM.Codegen.JoinAliasSpec (joinAliasSpec)
import ORM.Codegen.TargetSpec (targetSpec)
import ORM.Codegen.ValidateSpec (validateSpec)
import ORM.ErrorsSpec (errorsSpec)
import ORM.GroupSpec (groupSpec)
import ORM.IncludeSpec (includeSpec)
import ORM.JoinSpec (joinSpec)
import ORM.OperationsSpec (operationsSpec)
import ORM.RawSpec (rawSpec)
import ORM.WhereSpec (whereSpec)
import Support.TestDb (withTestDb)
import Test.Hspec

main :: IO ()
main = hspec $ do
  validateSpec
  joinAliasSpec
  includePathSpec
  fourLevelPathSpec
  emitSpec
  emitFlatRowSpec
  emitIncludeSpec
  emitClientSpec
  targetSpec
  errorsSpec
  groupSpec
  whereSpec
  withTestDb $ operationsSpec >> joinSpec >> includeSpec >> rawSpec
