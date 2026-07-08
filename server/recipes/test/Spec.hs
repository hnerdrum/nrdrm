module Main (main) where

import ORM.OperationsSpec (operationsSpec)
import Support.TestDb (withTestDb)
import Test.Hspec

main :: IO ()
main = hspec $ withTestDb operationsSpec
