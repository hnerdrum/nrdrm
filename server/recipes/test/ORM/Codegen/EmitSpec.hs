{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitSpec
  ( emitSpec,
  )
where

import qualified Data.Text as T
import qualified Data.Text.IO as T
import ORM.Codegen.Emit.Schema (emitModelModule)
import ORM.Codegen.Spec.Widget (widgetModel)
import Test.Hspec

emitSpec :: Spec
emitSpec =
  describe "ORM.Codegen.Emit.Schema" $ do
    it "emits Widget matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/Widget.hs"
      let actual = emitModelModule "Schema.Widget" widgetModel
      T.strip actual `shouldBe` T.strip expected
