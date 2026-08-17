{-# LANGUAGE LambdaCase #-}

module ORM.OperationsSpec
  ( operationsSpec,
  )
where

import Data.List (sort)
import Data.UUID (UUID, nil)
import ORM (NullableValue (..), ORMError (..), runDb)
import qualified ORM.Delete as Delete
import qualified ORM.Insert as Insert
import qualified ORM.Operations as Ops
import ORM.Query (OrderDirection (Asc), limit, offset, orderBy, whereEq)
import qualified ORM.Update as Update
import qualified ORM.WidgetFixtures as WidgetFixtures
import Schema.Book (BookCreate (..), BookRow (..), BookTable)
import Schema.Widget (WidgetCreate (..), WidgetRow (..), WidgetTable (..), WidgetUpdate (..), widgetCreatedAt, widgetId, widgetName)
import Support.Assert (assertJust, assertRight)
import Support.TestDb (TestEnv (..))
import Test.Hspec (SpecWith, describe, it, shouldBe, shouldSatisfy)

operationsSpec :: SpecWith TestEnv
operationsSpec =
  describe "ORM.Operations" $ do
    it "findMany returns an empty list on a clean test_widget table" $ \TestEnv {envPool = pool} -> do
      rows <- runDb pool (Ops.findMany @WidgetTable @WidgetRow id)
      rows `shouldBe` []

    it "findMany returns all rows in table" $ \TestEnv {envPool = pool} -> do
      alpha <- WidgetFixtures.insertWidget pool "alpha"
      beta <- WidgetFixtures.insertWidget pool "beta"
      gamma <- WidgetFixtures.insertWidget pool "gamma"
      results <- runDb pool (Ops.findMany @WidgetTable @WidgetRow id)
      sort (map (.id) results) `shouldBe` sort [alpha.id, beta.id, gamma.id]

    it "findUnique returns an element by id" $ \TestEnv {envPool = pool} -> do
      widget <- WidgetFixtures.insertWidget pool "test"
      result <- runDb pool (Ops.findUnique @WidgetTable @WidgetRow widget.id)
      result `shouldBe` Just widget

    it "findMany returns all elements that pass the filter" $ \TestEnv {envPool = pool} -> do
      alpha1 <- WidgetFixtures.insertWidget pool "alpha"
      alpha2 <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "beta"
      results <- runDb pool (Ops.findMany @WidgetTable @WidgetRow $ whereEq widgetName "alpha")
      sort (map (.id) results) `shouldBe` sort [alpha1.id, alpha2.id]

    it "findUniqueOrFail returns an element by id" $ \TestEnv {envPool = pool} -> do
      widget <- WidgetFixtures.insertWidget pool "test"
      result <- runDb pool (Ops.findUniqueOrFail @WidgetTable @WidgetRow widget.id)
      result `shouldBe` Right widget

    it "findUniqueOrFail returns an error if no element is found" $ \TestEnv {envPool = pool} -> do
      result <- runDb pool (Ops.findUniqueOrFail @WidgetTable @WidgetRow (nil :: UUID))
      result
        `shouldSatisfy` ( \case
                            Left (RecordNotFound _) -> True
                            _ -> False
                        )

    it "findFirst returns the first element that passes the filter" $ \TestEnv {envPool = pool} -> do
      alpha1 <- WidgetFixtures.insertWidget pool "alpha"
      alpha2 <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "beta"
      result <- runDb pool (Ops.findFirst @WidgetTable @WidgetRow $ whereEq widgetName "alpha")
      row <- assertJust result
      row.name `shouldBe` "alpha"
      row.id `shouldSatisfy` (`elem` [alpha1.id, alpha2.id])

    it "findFirst returns Nothing when no row matches" $ \TestEnv {envPool = pool} -> do
      result <- runDb pool (Ops.findFirst @WidgetTable @WidgetRow $ whereEq widgetName "nonexistent")
      result `shouldBe` Nothing

    it "count returns the number of rows matching a filter" $ \TestEnv {envPool = pool} -> do
      _ <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "beta"
      n <- runDb pool (Ops.count @WidgetTable $ whereEq widgetName "alpha")
      n `shouldBe` 2

    it "count returns 0 when no rows match" $ \TestEnv {envPool = pool} -> do
      n <- runDb pool (Ops.count @WidgetTable $ whereEq widgetName "nonexistent")
      n `shouldBe` 0

    it "update changes a widget name by id" $ \TestEnv {envPool = pool} -> do
      widget <- WidgetFixtures.insertWidget pool "before"
      updated <-
        runDb
          pool
          ( Update.update @WidgetTable @WidgetRow
              widget.id
              WidgetUpdate
                { name = Just "after",
                  createdAt = Nothing,
                  updatedAt = Nothing,
                  description = Omit
                }
          )
          >>= assertRight
      updated.name `shouldBe` "after"
      found <- runDb pool (Ops.findUnique @WidgetTable @WidgetRow widget.id)
      found `shouldBe` Just updated

    it "update with Omit leaves description unchanged" $ \TestEnv {envPool = pool} -> do
      widget <-
        runDb
          pool
          ( Insert.insert @WidgetTable @WidgetRow
              WidgetCreate
                { id = Nothing,
                  createdAt = Nothing,
                  updatedAt = Nothing,
                  name = "widget",
                  description = Value "keep me"
                }
          )
          >>= assertRight
      updated <-
        runDb
          pool
          ( Update.update @WidgetTable @WidgetRow
              widget.id
              WidgetUpdate
                { name = Just "renamed",
                  createdAt = Nothing,
                  updatedAt = Nothing,
                  description = Omit
                }
          )
          >>= assertRight
      updated.name `shouldBe` "renamed"
      updated.description `shouldBe` Just "keep me"

    it "insert with Null sets description to NULL" $ \TestEnv {envPool = pool} -> do
      widget <-
        runDb
          pool
          ( Insert.insert @WidgetTable @WidgetRow
              WidgetCreate
                { id = Nothing,
                  createdAt = Nothing,
                  updatedAt = Nothing,
                  name = "widget",
                  description = Null
                }
          )
          >>= assertRight
      widget.description `shouldBe` Nothing

    it "update with Null clears description" $ \TestEnv {envPool = pool} -> do
      widget <-
        runDb
          pool
          ( Insert.insert @WidgetTable @WidgetRow
              WidgetCreate
                { id = Nothing,
                  createdAt = Nothing,
                  updatedAt = Nothing,
                  name = "widget",
                  description = Value "keep me"
                }
          )
          >>= assertRight
      updated <-
        runDb
          pool
          ( Update.update @WidgetTable @WidgetRow
              widget.id
              WidgetUpdate
                { name = Nothing,
                  createdAt = Nothing,
                  updatedAt = Nothing,
                  description = Null
                }
          )
          >>= assertRight
      updated.description `shouldBe` Nothing

    it "findMany supports offset" $ \TestEnv {envPool = pool} -> do
      _ <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "alpha"
      _ <- WidgetFixtures.insertWidget pool "alpha"
      allAlpha <- runDb pool (Ops.findMany @WidgetTable @WidgetRow $ whereEq widgetName "alpha")
      paged <-
        runDb
          pool
          ( Ops.findMany @WidgetTable @WidgetRow $
              offset 1 . limit 1 . orderBy widgetCreatedAt Asc . whereEq widgetName "alpha"
          )
      length allAlpha `shouldBe` 3
      length paged `shouldBe` 1

    it "delete removes a widget by id" $ \TestEnv {envPool = pool} -> do
      widget <- WidgetFixtures.insertWidget pool "doomed"
      deleted <- runDb pool (Ops.delete @WidgetTable widget.id)
      deleted `shouldBe` 1
      found <- runDb pool (Ops.findUnique @WidgetTable @WidgetRow widget.id)
      found `shouldBe` Nothing

    it "delete returns 0 when no row matches" $ \TestEnv {envPool = pool} -> do
      deleted <- runDb pool (Ops.delete @WidgetTable (nil :: UUID))
      deleted `shouldBe` 0

    it "deleteMany id returns EmptyWhere" $ \TestEnv {envPool = pool} -> do
      result <- runDb pool (Delete.deleteMany @WidgetTable id)
      result
        `shouldSatisfy` ( \case
                            Left (EmptyWhere _) -> True
                            _ -> False
                        )

    it "updateBuilder without WHERE returns EmptyWhere" $ \TestEnv {envPool = pool} -> do
      result <-
        runDb
          pool
          ( Update.updateBuilder @WidgetTable @WidgetRow $
              Update.setField widgetName "x" (Update.emptyUpdate @WidgetTable)
          )
      result
        `shouldSatisfy` ( \case
                            Left (EmptyWhere _) -> True
                            _ -> False
                        )

    it "insert maps not-null violations" $ \TestEnv {envPool = pool} -> do
      result <-
        runDb
          pool
          ( Insert.insertBuilder @WidgetTable @WidgetRow $
              Insert.set widgetId nil (Insert.emptyInsert @WidgetTable)
          )
      result
        `shouldSatisfy` ( \case
                            Left (NotNullViolation _) -> True
                            _ -> False
                        )

    it "insert maps foreign key violations" $ \TestEnv {envPool = pool} -> do
      result <-
        runDb
          pool
          ( Insert.insert @BookTable @BookRow
              BookCreate
                { id = Nothing,
                  shelfId = nil,
                  title = "ghost"
                }
          )
      result
        `shouldSatisfy` ( \case
                            Left (ForeignKeyViolation _) -> True
                            _ -> False
                        )