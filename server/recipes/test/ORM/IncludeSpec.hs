{-# LANGUAGE TypeApplications #-}

module ORM.IncludeSpec
  ( includeSpec,
  )
where

import Data.List (sort)
import Data.UUID (UUID)
import ORM.Include (findManyWith)
import ORM.Query (whereEq)
import qualified ORM.ShelfFixtures as ShelfFixtures
import Schema.Shelf (shelfName)
import qualified Schema.Shelf as Shelf
import Schema.ShelfInclude (ShelfInclude (..), ShelfWithBooks (..))
import Support.TestDb (TestEnv (..))
import Test.Hspec (SpecWith, describe, it, shouldBe)

includeSpec :: SpecWith TestEnv
includeSpec =
  describe "ORM.Include" $ do
    it "findManyWith nests books under their shelf" $ \TestEnv {envPool = pool} -> do
      fiction <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertShelf pool "nonfiction"
      _ <- ShelfFixtures.insertBook pool fiction.id "Dune"
      _ <- ShelfFixtures.insertBook pool fiction.id "Neuromancer"
      results <-
        findManyWith @Shelf.ShelfTable
          pool
          ShelfInclude {books = True}
          id
      length results `shouldBe` 2
      fictionResult <- lookupShelf fiction.id results
      sort (map (.title) fictionResult.books) `shouldBe` ["Dune", "Neuromancer"]

    it "findManyWith includes a shelf with no books as empty list" $ \TestEnv {envPool = pool} -> do
      empty <- ShelfFixtures.insertShelf pool "empty"
      stocked <- ShelfFixtures.insertShelf pool "stocked"
      _ <- ShelfFixtures.insertBook pool stocked.id "Book"
      results <-
        findManyWith @Shelf.ShelfTable
          pool
          ShelfInclude {books = True}
          id
      emptyResult <- lookupShelf empty.id results
      emptyResult.books `shouldBe` []

    it "findManyWith without include uses single-table read" $ \TestEnv {envPool = pool} -> do
      _ <- ShelfFixtures.insertShelf pool "alpha"
      _ <- ShelfFixtures.insertShelf pool "beta"
      results <-
        findManyWith @Shelf.ShelfTable
          pool
          ShelfInclude {books = False}
          id
      length results `shouldBe` 2
      map (.books) results `shouldBe` [[], []]

    it "findManyWith applies root filter before nesting" $ \TestEnv {envPool = pool} -> do
      fiction <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertShelf pool "nonfiction"
      _ <- ShelfFixtures.insertBook pool fiction.id "Dune"
      results <-
        findManyWith @Shelf.ShelfTable
          pool
          ShelfInclude {books = True}
          (whereEq shelfName "fiction")
      length results `shouldBe` 1
      (head results).shelf.name `shouldBe` "fiction"
      map (.title) (head results).books `shouldBe` ["Dune"]

lookupShelf :: UUID -> [ShelfWithBooks] -> IO ShelfWithBooks
lookupShelf shelfId results =
  case filter ((== shelfId) . (.id) . (.shelf)) results of
    [shelf] -> pure shelf
    _ -> fail "expected exactly one shelf in results"
