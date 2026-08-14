{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitIncludeSpec
  ( emitIncludeSpec,
  )
where

import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import ORM.Codegen.Emit.Include
  ( emitBuildJoinChain,
    emitDeepJoinBuilder,
    emitDeepNestHelpers,
    emitExecuteInclude,
    emitIncludeADTs,
    emitIncludeModule,
    emitIncludesJoin,
    emitNestInclude,
    emitResultADTs,
    emitShallowJoinBuilder,
    emitShallowNestHelpers,
  )
import ORM.Codegen.IR (Schema (..))
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import Test.Hspec

emitIncludeSpec :: Spec
emitIncludeSpec =
  describe "ORM.Codegen.Emit.Include" $ do
    it "emits ShelfInclude and BookInclude ADTs" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitIncludeADTs shelfSchema incl)
        `shouldBe` T.strip expectedShelfIncludeADTs

    it "emits ShelfWithBooks and BookWithChapters result ADTs" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitResultADTs shelfSchema incl)
        `shouldBe` T.strip expectedShelfResultADTs

    it "emits IncludesJoin for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitIncludesJoin shelfSchema incl)
        `shouldBe` T.strip expectedIncludesJoin

    it "emits buildShelfBookJoin" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitShallowJoinBuilder shelfSchema incl)
        `shouldBe` T.strip expectedShelfBookJoin

    it "emits buildShelfBookChapterJoin" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitDeepJoinBuilder shelfSchema incl)
        `shouldBe` T.strip expectedShelfBookChapterJoin

    it "emits BuildJoinChain for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitBuildJoinChain shelfSchema incl)
        `shouldBe` T.strip expectedBuildJoinChain

    it "emits NestInclude for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitNestInclude shelfSchema incl)
        `shouldBe` T.strip expectedNestInclude

    it "emits shallow nest helpers for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitShallowNestHelpers shelfSchema incl)
        `shouldBe` T.strip expectedShallowNestHelpers

    it "emits deep nest helpers for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitDeepNestHelpers shelfSchema incl)
        `shouldBe` T.strip expectedDeepNestHelpers

    it "emits OVERLAPPING ExecuteInclude for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitExecuteInclude shelfSchema incl)
        `shouldBe` T.strip expectedExecuteInclude

    it "emits ShelfInclude module matching the golden file" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/ShelfInclude.hs.golden"
      let incl = head (schemaIncludes shelfSchema)
          actual = emitIncludeModule "Schema.ShelfInclude" shelfSchema incl
      T.strip actual `shouldBe` T.strip expected

    it "emits RecipeInclude module matching the golden file" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/RecipeInclude.hs.golden"
      let incl = head (schemaIncludes recipeSchema)
          actual = emitIncludeModule "ORM.Schema.RecipeInclude" recipeSchema incl
      T.strip actual `shouldBe` T.strip expected

expectedShelfIncludeADTs :: T.Text
expectedShelfIncludeADTs =
  T.unlines
    [ "newtype BookInclude = BookInclude",
      "  { chapters :: Bool",
      "  }",
      "  deriving (Show, Eq)",
      "",
      "newtype ShelfInclude = ShelfInclude",
      "  { books :: Maybe BookInclude",
      "  }",
      "  deriving (Show, Eq)"
    ]

expectedShelfResultADTs :: T.Text
expectedShelfResultADTs =
  T.unlines
    [ "data BookWithChapters = BookWithChapters",
      "  { book :: BookRow,",
      "    chapters :: [ChapterRow]",
      "  }",
      "  deriving (Show, Eq)",
      "",
      "data ShelfWithBooks = ShelfWithBooks",
      "  { shelf :: ShelfRow,",
      "    books :: [BookWithChapters]",
      "  }",
      "  deriving (Show, Eq)"
    ]

expectedIncludesJoin :: T.Text
expectedIncludesJoin =
  T.unlines
    [ "instance IncludesJoin ShelfInclude where",
      "  includesJoin ShelfInclude {books} = isJust books"
    ]

expectedShelfBookJoin :: T.Text
expectedShelfBookJoin =
  T.unlines
    [ "buildShelfBookJoin :: JoinChain.JoinChain ShelfTable",
      "buildShelfBookJoin =",
      "  JoinChain.selectColumns shelfBookColumns $",
      "    JoinChain.buildJoinChainFromHasMany shelfBooks \"s\" \"b\""
    ]

expectedShelfBookChapterJoin :: T.Text
expectedShelfBookChapterJoin =
  T.unlines
    [ "buildShelfBookChapterJoin :: JoinChain.JoinChain ShelfTable",
      "buildShelfBookChapterJoin =",
      "  JoinChain.selectColumns shelfBookChapterColumns $",
      "    JoinChain.addHasManyJoin bookChapters \"b\" \"c\" buildShelfBookJoin"
    ]

expectedBuildJoinChain :: T.Text
expectedBuildJoinChain =
  T.unlines
    [ "instance BuildJoinChain ShelfTable ShelfInclude where",
      "  type JoinFlatRow ShelfInclude = ShelfBookJoinRow",
      "  buildJoinChain ShelfInclude {books = Just BookInclude {chapters = False}} =",
      "    buildShelfBookJoin",
      "  buildJoinChain ShelfInclude {books = Just BookInclude {chapters = True}} =",
      "    buildShelfBookChapterJoin",
      "  buildJoinChain ShelfInclude {books = Nothing} =",
      "    buildShelfBookJoin"
    ]

expectedNestInclude :: T.Text
expectedNestInclude =
  T.unlines
    [ "instance NestInclude ShelfInclude ShelfWithBooks where",
      "  type RootRow ShelfInclude = ShelfRow",
      "  nestRows _ = nestShelfRows",
      "  wrapRoot _ shelf = ShelfWithBooks {shelf, books = []}"
    ]

expectedShallowNestHelpers :: T.Text
expectedShallowNestHelpers =
  T.unlines
    [ "nestShelfRows :: [ShelfBookJoinRow] -> [ShelfWithBooks]",
      "nestShelfRows =",
      "  map shelfWithBooksFromGroup . groupByKey (.shelfId)",
      "",
      "shelfWithBooksFromGroup :: [ShelfBookJoinRow] -> ShelfWithBooks",
      "shelfWithBooksFromGroup rows@(firstRow : _) =",
      "  ShelfWithBooks",
      "    { shelf = toShelfRow firstRow,",
      "      books = map bookWithNoChapters $ mapMaybe toBookRow rows",
      "    }",
      "shelfWithBooksFromGroup [] =",
      "  error \"shelfWithBooksFromGroup: empty group\"",
      "",
      "bookWithNoChapters :: BookRow -> BookWithChapters",
      "bookWithNoChapters book = BookWithChapters {book, chapters = []}",
      "",
      "toShelfRow :: ShelfBookJoinRow -> ShelfRow",
      "toShelfRow row = ShelfRow {id = row.shelfId, name = row.shelfName}",
      "",
      "toBookRow :: ShelfBookJoinRow -> Maybe BookRow",
      "toBookRow row",
      "  | Just bid <- row.bookId,",
      "    Just title <- row.bookTitle =",
      "      Just BookRow {id = bid, title = title, shelfId = row.shelfId}",
      "  | otherwise = Nothing"
    ]

expectedDeepNestHelpers :: T.Text
expectedDeepNestHelpers =
  T.unlines
    [ "nestShelfBookChapterRows :: [ShelfBookChapterJoinRow] -> [ShelfWithBooks]",
      "nestShelfBookChapterRows =",
      "  map shelfWithChaptersFromShelfGroup . groupByKey (.shelfId)",
      "",
      "shelfWithChaptersFromShelfGroup :: [ShelfBookChapterJoinRow] -> ShelfWithBooks",
      "shelfWithChaptersFromShelfGroup rows@(firstRow : _) =",
      "  ShelfWithBooks",
      "    { shelf = toShelfRowFromChapter firstRow,",
      "      books = mapMaybe bookWithChaptersFromGroup $ groupByKey (.bookId) rows",
      "    }",
      "shelfWithChaptersFromShelfGroup [] =",
      "  error \"shelfWithChaptersFromShelfGroup: empty group\"",
      "",
      "bookWithChaptersFromGroup :: [ShelfBookChapterJoinRow] -> Maybe BookWithChapters",
      "bookWithChaptersFromGroup rows@(firstRow : _)",
      "  | Just _ <- firstRow.bookId =",
      "      Just",
      "        BookWithChapters",
      "          { book = toBookRowFromChapter firstRow,",
      "            chapters = mapMaybe toChapterRow rows",
      "          }",
      "  | otherwise = Nothing",
      "bookWithChaptersFromGroup [] = Nothing",
      "",
      "toShelfRowFromChapter :: ShelfBookChapterJoinRow -> ShelfRow",
      "toShelfRowFromChapter row = ShelfRow {id = row.shelfId, name = row.shelfName}",
      "",
      "toBookRowFromChapter :: ShelfBookChapterJoinRow -> BookRow",
      "toBookRowFromChapter row =",
      "  BookRow",
      "    { id = fromMaybe (error \"toBookRowFromChapter: missing id\") row.bookId,",
      "      title = fromMaybe (error \"toBookRowFromChapter: missing title\") row.bookTitle,",
      "      shelfId = row.shelfId",
      "    }",
      "",
      "toChapterRow :: ShelfBookChapterJoinRow -> Maybe ChapterRow",
      "toChapterRow row",
      "  | Just cid <- row.chapterId,",
      "    Just heading <- row.chapterHeading,",
      "    Just bid <- row.bookId =",
      "      Just ChapterRow {id = cid, heading = heading, bookRef = bid}",
      "  | otherwise = Nothing"
    ]

expectedExecuteInclude :: T.Text
expectedExecuteInclude =
  T.unlines
    [ "instance {-# OVERLAPPING #-} ExecuteInclude ShelfTable ShelfInclude ShelfWithBooks where",
      "  executeInclude conn include modifier =",
      "    case include.books of",
      "      Nothing -> do",
      "        roots <- findManyConn @ShelfTable @ShelfRow conn modifier",
      "        pure $ map (wrapRoot include) roots",
      "      Just BookInclude {chapters = False} -> do",
      "        let chain = applyRootFilter buildShelfBookJoin modifier",
      "        flatRows <- JoinChain.runJoinChainConn @ShelfBookJoinRow conn chain",
      "        pure $ nestShelfRows flatRows",
      "      Just BookInclude {chapters = True} -> do",
      "        let chain = applyRootFilter buildShelfBookChapterJoin modifier",
      "        flatRows <- JoinChain.runJoinChainConn @ShelfBookChapterJoinRow conn chain",
      "        pure $ nestShelfBookChapterRows flatRows"
    ]
