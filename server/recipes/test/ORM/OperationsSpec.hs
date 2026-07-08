{-# LANGUAGE LambdaCase #-}

module ORM.OperationsSpec
  ( operationsSpec,
  )
where

import Data.List (sort)
import Data.UUID (UUID, nil)
import ORM (ORMError (..))
import qualified ORM.Operations as Ops
import ORM.Query (whereEq)
import qualified ORM.WidgetFixtures as WidgetFixtures
import Schema.Widget (WidgetRow (..), WidgetTable (..), widgetName)
import Support.TestDb (TestEnv (..))
import Test.Hspec (SpecWith, describe, expectationFailure, it, shouldBe, shouldSatisfy)

operationsSpec :: SpecWith TestEnv
operationsSpec =
  describe "ORM.Operations" $ do
    it "findAll returns an empty list on a clean test_widget table" $ \TestEnv {envPool = pool} -> do
      rows <- Ops.findAll @WidgetTable @WidgetRow pool
      rows `shouldBe` []

    it "findAll return all rows in table" $ \TestEnv {envPool = pool} -> do
      alpha <- WidgetFixtures.insertWidget pool "alpha"
      beta <- WidgetFixtures.insertWidget pool "beta"
      gamma <- WidgetFixtures.insertWidget pool "gamma"
      results <- Ops.findAll @WidgetTable @WidgetRow pool
      sort (map (.id) results) `shouldBe` sort [alpha.id, beta.id, gamma.id]

    it "findUnique returns an element by id" $ \TestEnv {envPool = pool} -> do
      widget <- WidgetFixtures.insertWidget pool "test"
      result <- Ops.findUnique @WidgetTable @WidgetRow pool widget.id
      result `shouldBe` Just widget

    it "findMany returns all elements that pass the filter" $ \TestEnv {envPool = pool} -> do
      alpha1 <- WidgetFixtures.insertWidget pool "alpha"
      alpha2 <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "beta"
      results <- Ops.findMany @WidgetTable @WidgetRow pool $ whereEq widgetName "alpha"
      sort (map (.id) results) `shouldBe` sort [alpha1.id, alpha2.id]

    it "findUniqueOrError returns an element by id" $ \TestEnv {envPool = pool} -> do
      widget <- WidgetFixtures.insertWidget pool "test"
      result <- Ops.findUniqueOrError @WidgetTable @WidgetRow pool widget.id
      result `shouldBe` Right widget

    it "findUniqueOrError returns an error if no element is found" $ \TestEnv {envPool = pool} -> do
      result <- Ops.findUniqueOrError @WidgetTable @WidgetRow pool (nil :: UUID)
      result
        `shouldSatisfy` ( \case
                            Left (RecordNotFound _) -> True
                            _ -> False
                        )

    it "findFirst returns the first element that passes the filter" $ \TestEnv {envPool = pool} -> do
      alpha1 <- WidgetFixtures.insertWidget pool "alpha"
      alpha2 <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "beta"
      result <- Ops.findFirst @WidgetTable @WidgetRow pool $ whereEq widgetName "alpha"
      case result of
        Just row -> do
          row.name `shouldBe` "alpha"
          row.id `shouldSatisfy` (`elem` [alpha1.id, alpha2.id])
        Nothing -> expectationFailure "expected Just"

    it "findFirst returns Nothing when no row matches" $ \TestEnv {envPool = pool} -> do
      result <- Ops.findFirst @WidgetTable @WidgetRow pool $ whereEq widgetName "nonexistent"
      result `shouldBe` Nothing

    it "count returns the number of rows matching a filter" $ \TestEnv {envPool = pool} -> do
      _ <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "beta"
      n <- Ops.count @WidgetTable pool $ whereEq widgetName "alpha"
      n `shouldBe` 2

    it "count returns 0 when no rows match" $ \TestEnv {envPool = pool} -> do
      n <- Ops.count @WidgetTable pool $ whereEq widgetName "nonexistent"
      n `shouldBe` 0