{-# LANGUAGE TypeApplications #-}

module ORM.IncludeSpec
  ( includeSpec,
  )
where

import Data.List (sort)
import Data.Text (Text)
import Data.UUID (UUID, nil)
import ORM.Include (findAllWith, findManyWith, findUniqueWith)
import ORM.Query (whereEq)
import qualified ORM.ShelfFixtures as ShelfFixtures
import Schema.Book (BookRow (..))
import Schema.Chapter (ChapterRow (..))
import Schema.Shelf (shelfName)
import qualified Schema.Shelf as Shelf
import Schema.ShelfInclude
  ( BookInclude (..),
    BookWithChapters (..),
    ShelfInclude (..),
    ShelfWithBooks (..),
  )
import Support.TestDb (TestEnv (..))
import Test.Hspec (SpecWith, describe, it, shouldBe)

includeBooks :: ShelfInclude
includeBooks = ShelfInclude {books = Just (BookInclude {chapters = False})}

includeBooksChapters :: ShelfInclude
includeBooksChapters = ShelfInclude {books = Just (BookInclude {chapters = True})}

includeSpec :: SpecWith TestEnv
includeSpec =
  describe "ORM.Include" $ do
    it "findManyWith nests books under their shelf" $ \TestEnv {envPool = pool} -> do
      fiction <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertShelf pool "nonfiction"
      _ <- ShelfFixtures.insertBook pool fiction.id "Dune"
      _ <- ShelfFixtures.insertBook pool fiction.id "Neuromancer"
      results <- findManyWith @Shelf.ShelfTable pool includeBooks id
      length results `shouldBe` 2
      fictionResult <- lookupShelf fiction.id results
      sort (map ((.title) . (.book)) fictionResult.books) `shouldBe` ["Dune", "Neuromancer"]

    it "findManyWith includes a shelf with no books as empty list" $ \TestEnv {envPool = pool} -> do
      empty <- ShelfFixtures.insertShelf pool "empty"
      stocked <- ShelfFixtures.insertShelf pool "stocked"
      _ <- ShelfFixtures.insertBook pool stocked.id "Book"
      results <- findManyWith @Shelf.ShelfTable pool includeBooks id
      emptyResult <- lookupShelf empty.id results
      emptyResult.books `shouldBe` []

    it "findManyWith without include uses single-table read" $ \TestEnv {envPool = pool} -> do
      _ <- ShelfFixtures.insertShelf pool "alpha"
      _ <- ShelfFixtures.insertShelf pool "beta"
      results <- findManyWith @Shelf.ShelfTable pool (ShelfInclude {books = Nothing}) id
      length results `shouldBe` 2
      map (.books) results `shouldBe` [[], []]

    it "findManyWith applies root filter before nesting" $ \TestEnv {envPool = pool} -> do
      fiction <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertShelf pool "nonfiction"
      _ <- ShelfFixtures.insertBook pool fiction.id "Dune"
      results <-
        findManyWith @Shelf.ShelfTable pool includeBooks (whereEq shelfName "fiction")
      length results `shouldBe` 1
      (head results).shelf.name `shouldBe` "fiction"
      map ((.title) . (.book)) (head results).books `shouldBe` ["Dune"]

    it "findManyWith nests chapters under books" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      book <- ShelfFixtures.insertBook pool shelf.id "Dune"
      _ <- ShelfFixtures.insertChapter pool book.id "Arrakis"
      _ <- ShelfFixtures.insertChapter pool book.id "Caladan"
      results <- findManyWith @Shelf.ShelfTable pool includeBooksChapters id
      [result] <- pure results
      result.shelf.name `shouldBe` "fiction"
      [bookWithChapters] <- pure result.books
      (.title) bookWithChapters.book `shouldBe` "Dune"
      sort (map (.heading) bookWithChapters.chapters) `shouldBe` ["Arrakis", "Caladan"]

    it "findManyWith includes a book with no chapters as empty list" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      book <- ShelfFixtures.insertBook pool shelf.id "Dune"
      _ <- ShelfFixtures.insertBook pool shelf.id "Neuromancer"
      _ <- ShelfFixtures.insertChapter pool book.id "Chiba"
      results <- findManyWith @Shelf.ShelfTable pool includeBooksChapters id
      [result] <- pure results
      dune <- lookupBook "Dune" result
      neuromancer <- lookupBook "Neuromancer" result
      map (.heading) dune.chapters `shouldBe` ["Chiba"]
      neuromancer.chapters `shouldBe` []

    it "findAllWith returns all nested results" $ \TestEnv {envPool = pool} -> do
      _ <- ShelfFixtures.insertShelf pool "one"
      _ <- ShelfFixtures.insertShelf pool "two"
      results <- findAllWith @Shelf.ShelfTable pool includeBooks
      length results `shouldBe` 2

    it "findUniqueWith returns Just for an existing primary key" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertBook pool shelf.id "Dune"
      result <- findUniqueWith @Shelf.ShelfTable pool includeBooks shelf.id
      fmap ((.name) . (.shelf)) result `shouldBe` Just "fiction"

    it "findUniqueWith returns Nothing when missing" $ \TestEnv {envPool = pool} -> do
      result <- findUniqueWith @Shelf.ShelfTable pool includeBooks (nil :: UUID)
      result `shouldBe` Nothing

lookupShelf :: UUID -> [ShelfWithBooks] -> IO ShelfWithBooks
lookupShelf shelfId results =
  case filter ((== shelfId) . (.id) . (.shelf)) results of
    [shelf] -> pure shelf
    _ -> fail "expected exactly one shelf in results"

lookupBook :: Text -> ShelfWithBooks -> IO BookWithChapters
lookupBook title result =
  case filter ((== title) . (.title) . (.book)) result.books of
    [book] -> pure book
    _ -> fail "expected exactly one book in results"
