module Main (main) where

import ORM.IncludeSpec (includeSpec)
import ORM.JoinSpec (joinSpec)
import ORM.OperationsSpec (operationsSpec)
import Support.TestDb (withTestDb)
import Test.Hspec

main :: IO ()
main = hspec $ withTestDb $ operationsSpec >> joinSpec >> includeSpec
