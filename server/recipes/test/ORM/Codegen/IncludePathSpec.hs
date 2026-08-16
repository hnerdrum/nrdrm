{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.IncludePathSpec
  ( includePathSpec,
    fourLevelPathSpec,
  )
where

import ORM.Codegen.IR
import ORM.Codegen.IncludePath
  ( columnListName,
    includeLongestJoinPath,
    includeMaxDepth,
    includePresetJoinPaths,
    joinBuilderName,
    joinPathModels,
    joinPathTake,
    joinRowName,
  )
import ORM.Codegen.Spec.Shelf (shelfSchema)
import ORM.Codegen.Spec.ShelfDeep (shelfDeepSchema)
import Test.Hspec

includePathSpec :: Spec
includePathSpec =
  describe "ORM.Codegen.IncludePath" $ do
    it "computes longest Shelf path as Shelf → Book → Chapter" $ do
      let incl = head (schemaIncludes shelfSchema)
          path = includeLongestJoinPath shelfSchema incl
      map modelName (joinPathModels path) `shouldBe` ["Shelf", "Book", "Chapter"]

    it "computes preset paths for shallow and deep joins" $ do
      let incl = head (schemaIncludes shelfSchema)
          paths = includePresetJoinPaths shelfSchema incl
      length paths `shouldBe` 2
      joinRowName (head paths) `shouldBe` "ShelfBookJoinRow"
      joinRowName (last paths) `shouldBe` "ShelfBookChapterJoinRow"

    it "names join builders from model path" $ do
      let incl = head (schemaIncludes shelfSchema)
          path = includeLongestJoinPath shelfSchema incl
      joinBuilderName (joinPathTake 1 path) `shouldBe` "buildShelfBookJoin"
      joinBuilderName path `shouldBe` "buildShelfBookChapterJoin"

    it "names column lists from model path" $ do
      let incl = head (schemaIncludes shelfSchema)
          path = includeLongestJoinPath shelfSchema incl
      columnListName (joinPathTake 1 path) `shouldBe` "shelfBookColumns"
      columnListName path `shouldBe` "shelfBookChapterColumns"

    it "reports include depth within default cap" $ do
      let incl = head (schemaIncludes shelfSchema)
      includeMaxDepth shelfSchema incl `shouldBe` 3

fourLevelPathSpec :: Spec
fourLevelPathSpec =
  describe "ORM.Codegen.IncludePath four-level fixture" $ do
    it "supports a 4-model join path" $ do
      let path = includeLongestJoinPath shelfDeepSchema shelfDeepInclude
      map modelName (joinPathModels path) `shouldBe` ["Shelf", "Book", "Chapter", "Section"]
      joinRowName path `shouldBe` "ShelfBookChapterSectionJoinRow"

shelfDeepInclude :: ModelInclude
shelfDeepInclude = head (schemaIncludes shelfDeepSchema)
