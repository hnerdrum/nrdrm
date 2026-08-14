{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitIncludeSpec
  ( emitIncludeSpec,
  )
where

import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import ORM.Codegen.Emit.Include
  ( emitIncludeADTs,
    emitIncludeModule,
    emitIncludesJoin,
    emitShallowBuildJoinChain,
    emitShallowJoinBuilder,
  )
import ORM.Codegen.IR (Schema (..))
import ORM.Codegen.Spec.Shelf (shelfSchema)
import Test.Hspec

emitIncludeSpec :: Spec
emitIncludeSpec =
  describe "ORM.Codegen.Emit.Include" $ do
    it "emits ShelfInclude and BookInclude ADTs" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitIncludeADTs shelfSchema incl)
        `shouldBe` T.strip expectedShelfIncludeADTs

    it "emits IncludesJoin for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitIncludesJoin shelfSchema incl)
        `shouldBe` T.strip expectedIncludesJoin

    it "emits buildShelfBookJoin" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitShallowJoinBuilder shelfSchema incl)
        `shouldBe` T.strip expectedShelfBookJoin

    it "emits shallow BuildJoinChain for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitShallowBuildJoinChain shelfSchema incl)
        `shouldBe` T.strip expectedBuildJoinChain

    it "emits ShelfInclude module matching the golden file" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/ShelfInclude.hs.golden"
      let incl = head (schemaIncludes shelfSchema)
          actual = emitIncludeModule "Schema.ShelfInclude" shelfSchema incl
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

expectedBuildJoinChain :: T.Text
expectedBuildJoinChain =
  T.unlines
    [ "instance BuildJoinChain ShelfTable ShelfInclude where",
      "  type JoinFlatRow ShelfInclude = ShelfBookJoinRow",
      "  buildJoinChain _ = buildShelfBookJoin"
    ]