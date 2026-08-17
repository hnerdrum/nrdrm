{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TypeApplications #-}

module ORM.IncludeSpec
  ( includeSpec,
  )
where

import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as T
import Data.UUID (UUID, nil)
import Database.PostgreSQL.Simple.ToField (toField)
import ORM (ORMError (..), runDb)
import ORM.Include (findMany, findUnique)
import qualified ORM.Operations as Ops
import ORM.Query (OrderDirection (Asc), limit, offset, orderBy, whereEq, where_)
import qualified ORM.ShelfFixtures as ShelfFixtures
import Schema.Book (BookRow (..))
import Schema.Chapter (ChapterRow (..))
import Schema.Section (SectionRow (..))
import Schema.Shelf (shelfName)
import qualified Schema.Shelf as Shelf
import Schema.ShelfDeepInclude (ChapterInclude (..), ShelfDeepInclude (..))
import qualified Schema.ShelfDeepInclude as ShelfDeepInclude
import Schema.ShelfGraphInclude
  ( ShelfGraphInclude (..),
    ShelfWithBooksTags (..),
  )
import qualified Schema.ShelfGraphInclude as ShelfGraphInclude
import Schema.ShelfInclude
  ( BookWithChapters (..),
    ShelfInclude (..),
    ShelfWithBooks (..),
  )
import qualified Schema.ShelfInclude as ShelfInclude
import Schema.Tag (TagRow (..))
import Support.TestDb (TestEnv (..))
import Test.Hspec (SpecWith, describe, it, shouldBe, shouldThrow)

includeBooks :: ShelfInclude
includeBooks = ShelfInclude {books = Just (ShelfInclude.BookInclude {chapters = False})}

includeBooksChapters :: ShelfInclude
includeBooksChapters = ShelfInclude {books = Just (ShelfInclude.BookInclude {chapters = True})}

includeBooksChaptersSections :: ShelfDeepInclude
includeBooksChaptersSections =
  ShelfDeepInclude
    { books =
        Just
          ShelfDeepInclude.BookInclude
            { chapters =
                Just ChapterInclude {sections = True}
            }
    }

includeBooksAndTags :: ShelfGraphInclude
includeBooksAndTags =
  ShelfGraphInclude
    { books = Just (ShelfGraphInclude.BookInclude {chapters = False}),
      tags = True
    }

includeSpec :: SpecWith TestEnv
includeSpec =
  describe "ORM.Include" $ do
    it "findMany nests books under their shelf" $ \TestEnv {envPool = pool} -> do
      fiction <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertShelf pool "nonfiction"
      _ <- ShelfFixtures.insertBook pool fiction.id "Dune"
      _ <- ShelfFixtures.insertBook pool fiction.id "Neuromancer"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooks id)
      length results `shouldBe` 2
      fictionResult <- lookupShelf fiction.id results
      let bookIds = map ((.id) . (.book)) fictionResult.books
      bookIds `shouldBe` sort bookIds
      sort (map ((.title) . (.book)) fictionResult.books) `shouldBe` ["Dune", "Neuromancer"]

    it "findMany includes a shelf with no books as empty list" $ \TestEnv {envPool = pool} -> do
      empty <- ShelfFixtures.insertShelf pool "empty"
      stocked <- ShelfFixtures.insertShelf pool "stocked"
      _ <- ShelfFixtures.insertBook pool stocked.id "Book"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooks id)
      emptyResult <- lookupShelf empty.id results
      emptyResult.books `shouldBe` []

    it "findMany without include uses single-table read" $ \TestEnv {envPool = pool} -> do
      _ <- ShelfFixtures.insertShelf pool "alpha"
      _ <- ShelfFixtures.insertShelf pool "beta"
      results <- runDb pool (Ops.findMany @Shelf.ShelfTable @Shelf.ShelfRow id)
      length results `shouldBe` 2
      sort (map (.name) results) `shouldBe` ["alpha", "beta"]

    it "findMany returns included roots in primary-key order" $ \TestEnv {envPool = pool} -> do
      firstShelf <- ShelfFixtures.insertShelf pool "first"
      secondShelf <- ShelfFixtures.insertShelf pool "second"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooks id)
      map ((.id) . (.shelf)) results `shouldBe` sort [firstShelf.id, secondShelf.id]

    it "findMany applies root filter before nesting" $ \TestEnv {envPool = pool} -> do
      fiction <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertShelf pool "nonfiction"
      _ <- ShelfFixtures.insertBook pool fiction.id "Dune"
      results <-
        runDb pool (findMany @Shelf.ShelfTable includeBooks (whereEq shelfName "fiction"))
      length results `shouldBe` 1
      (head results).shelf.name `shouldBe` "fiction"
      map ((.title) . (.book)) (head results).books `shouldBe` ["Dune"]

    it "findMany nests chapters under books" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      book <- ShelfFixtures.insertBook pool shelf.id "Dune"
      _ <- ShelfFixtures.insertChapter pool book.id "Arrakis"
      _ <- ShelfFixtures.insertChapter pool book.id "Caladan"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooksChapters id)
      [result] <- pure results
      result.shelf.name `shouldBe` "fiction"
      [bookWithChapters] <- pure result.books
      (.title) bookWithChapters.book `shouldBe` "Dune"
      let chapterIds = map (.id) bookWithChapters.chapters
      chapterIds `shouldBe` sort chapterIds
      sort (map (.heading) bookWithChapters.chapters) `shouldBe` ["Arrakis", "Caladan"]

    it "findMany includes a book with no chapters as empty list" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      book <- ShelfFixtures.insertBook pool shelf.id "Dune"
      _ <- ShelfFixtures.insertBook pool shelf.id "Neuromancer"
      _ <- ShelfFixtures.insertChapter pool book.id "Chiba"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooksChapters id)
      [result] <- pure results
      dune <- lookupBook "Dune" result
      neuromancer <- lookupBook "Neuromancer" result
      map (.heading) dune.chapters `shouldBe` ["Chiba"]
      neuromancer.chapters `shouldBe` []

    it "findMany returns all nested results" $ \TestEnv {envPool = pool} -> do
      _ <- ShelfFixtures.insertShelf pool "one"
      _ <- ShelfFixtures.insertShelf pool "two"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooks Prelude.id)
      length results `shouldBe` 2

    it "findUnique returns Just for an existing primary key" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertBook pool shelf.id "Dune"
      result <- runDb pool (findUnique @Shelf.ShelfTable includeBooks shelf.id)
      fmap ((.name) . (.shelf)) result `shouldBe` Just "fiction"

    it "findUnique returns all children for a parent with several has-many rows" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertBook pool shelf.id "Dune"
      _ <- ShelfFixtures.insertBook pool shelf.id "Neuromancer"
      result <- runDb pool (findUnique @Shelf.ShelfTable includeBooks shelf.id)
      let bookIds = maybe [] (map ((.id) . (.book)) . (.books)) result
      bookIds `shouldBe` sort bookIds
      fmap (sort . map ((.title) . (.book)) . (.books)) result
        `shouldBe` Just ["Dune", "Neuromancer"]

    it "findUnique includes a shelf with no books as Just with an empty list" $ \TestEnv {envPool = pool} -> do
      empty <- ShelfFixtures.insertShelf pool "empty"
      result <- runDb pool (findUnique @Shelf.ShelfTable includeBooks empty.id)
      fmap ((.name) . (.shelf)) result `shouldBe` Just "empty"
      fmap (.books) result `shouldBe` Just []

    it "findUnique returns Nothing when missing" $ \TestEnv {envPool = pool} -> do
      result <- runDb pool (findUnique @Shelf.ShelfTable includeBooks (nil :: UUID))
      result `shouldBe` Nothing

    it "findMany with include paginates parent rows" $ \TestEnv {envPool = pool} -> do
      mapM_ (\n -> ShelfFixtures.insertShelf pool ("shelf-" <> T.pack (show n))) ([1 .. 12] :: [Int])
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooks (limit 10))
      length results `shouldBe` 10

    it "findMany with include applies offset to parent rows" $ \TestEnv {envPool = pool} -> do
      _ <- ShelfFixtures.insertShelf pool "alpha"
      _ <- ShelfFixtures.insertShelf pool "bravo"
      _ <- ShelfFixtures.insertShelf pool "charlie"
      results <-
        runDb
          pool
          ( findMany @Shelf.ShelfTable includeBooks $
              offset 1 . limit 1 . orderBy shelfName Asc
          )
      length results `shouldBe` 1
      (head results).shelf.name `shouldBe` "bravo"

    it "findMany with include orders parent rows" $ \TestEnv {envPool = pool} -> do
      _ <- ShelfFixtures.insertShelf pool "zeta"
      _ <- ShelfFixtures.insertShelf pool "alpha"
      results <-
        runDb pool (findMany @Shelf.ShelfTable includeBooks (orderBy shelfName Asc))
      map ((.name) . (.shelf)) results `shouldBe` ["alpha", "zeta"]

    it "findMany with include rejects raw WHERE" $ \TestEnv {envPool = pool} -> do
      runDb
        pool
        ( findMany @Shelf.ShelfTable includeBooks $
            where_ "name = ?" [toField ("fiction" :: Text)]
        )
        `shouldThrow` isUnsupportedIncludeModifier

    it "findMany loads sibling hasMany collections independently" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      _ <- ShelfFixtures.insertBook pool shelf.id "Dune"
      _ <- ShelfFixtures.insertBook pool shelf.id "Neuromancer"
      _ <- ShelfFixtures.insertTag pool shelf.id "scifi"
      _ <- ShelfFixtures.insertTag pool shelf.id "classic"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooksAndTags id)
      [result] <- pure results
      sort (map ((.title) . (.book)) result.books) `shouldBe` ["Dune", "Neuromancer"]
      sort (map (.label) result.tags) `shouldBe` ["classic", "scifi"]

    it "findMany nests sections under chapters at four levels deep" $ \TestEnv {envPool = pool} -> do
      shelf <- ShelfFixtures.insertShelf pool "fiction"
      book <- ShelfFixtures.insertBook pool shelf.id "Dune"
      chapter <- ShelfFixtures.insertChapter pool book.id "Arrakis"
      _ <- ShelfFixtures.insertSection pool chapter.id "Desert"
      _ <- ShelfFixtures.insertSection pool chapter.id "Sietch"
      results <- runDb pool (findMany @Shelf.ShelfTable includeBooksChaptersSections id)
      [result] <- pure results
      [bookWithChapters] <- pure result.books
      [chapterWithSections] <- pure bookWithChapters.chapters
      let sectionIds = map (.id) chapterWithSections.sections
      sectionIds `shouldBe` sort sectionIds
      sort (map (.label) chapterWithSections.sections) `shouldBe` ["Desert", "Sietch"]

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

isUnsupportedIncludeModifier :: ORMError -> Bool
isUnsupportedIncludeModifier = \case
  UnsupportedIncludeModifier _ -> True
  _ -> False
