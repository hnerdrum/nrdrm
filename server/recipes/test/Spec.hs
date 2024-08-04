module Main (main) where

import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    describe "Test" $ do
      it "Should test something" $ do
        (2 :: Integer) `shouldBe` (2 :: Integer)
