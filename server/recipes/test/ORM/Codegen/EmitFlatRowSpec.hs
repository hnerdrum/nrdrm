{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitFlatRowSpec
  ( emitFlatRowSpec,
  )
where

import qualified Data.Text as T
import ORM.Codegen.Emit.FlatRow (emitShallowColumnList, emitShallowFlatJoinRow)
import ORM.Codegen.IR (Schema (..))
import ORM.Codegen.Spec.Shelf (shelfSchema)
import Test.Hspec

emitFlatRowSpec :: Spec
emitFlatRowSpec =
  describe "ORM.Codegen.Emit.FlatRow" $ do
    it "emits ShelfBookJoinRow for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitShallowFlatJoinRow shelfSchema incl)
        `shouldBe` T.strip expectedShelfBookJoinRow

    it "emits shelfBookColumns for ShelfInclude" $ do
      let incl = head (schemaIncludes shelfSchema)
      T.strip (emitShallowColumnList shelfSchema incl)
        `shouldBe` T.strip expectedShelfBookColumns

expectedShelfBookJoinRow :: T.Text
expectedShelfBookJoinRow =
  T.unlines
    [ "data ShelfBookJoinRow = ShelfBookJoinRow",
      "  { shelfId :: UUID,",
      "    shelfName :: Text,",
      "    bookId :: Maybe UUID,",
      "    bookTitle :: Maybe Text",
      "  }",
      "  deriving (Show, Eq)",
      "",
      "instance FromRow ShelfBookJoinRow where",
      "  fromRow = ShelfBookJoinRow <$> field <*> field <*> field <*> field"
    ]

expectedShelfBookColumns :: T.Text
expectedShelfBookColumns =
  T.unlines
    [ "shelfBookColumns :: [Text]",
      "shelfBookColumns =",
      "  [ JoinChain.col \"s\" Shelf.shelfId,",
      "    JoinChain.col \"s\" Shelf.shelfName,",
      "    JoinChain.col \"b\" Book.bookId,",
      "    JoinChain.col \"b\" Book.bookTitle",
      "  ]"
    ]