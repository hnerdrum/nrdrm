module Main (main) where

import ORM.Codegen.CLI (mainWith)
import ORM.Codegen.RecipeTarget (prodTarget)
import ORM.Codegen.Target (testTarget)

main :: IO ()
main = mainWith [testTarget, prodTarget] [prodTarget]
