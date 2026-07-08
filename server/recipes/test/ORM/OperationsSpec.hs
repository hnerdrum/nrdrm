module ORM.OperationsSpec
  ( operationsSpec,
  )
where

import qualified ORM.Operations as Ops
import Schema.Widget (WidgetRow, WidgetTable)
import Support.TestDb (TestEnv (..))
import Test.Hspec (SpecWith, describe, it, shouldBe)

operationsSpec :: SpecWith TestEnv
operationsSpec =
  describe "ORM.Operations" $ do
    it "findAll returns an empty list on a clean test_widget table" $ \TestEnv {envPool = pool} -> do
      rows <- Ops.findAll @WidgetTable @WidgetRow pool
      rows `shouldBe` []
