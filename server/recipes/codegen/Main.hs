module Main (main) where

import ORM.Codegen.RecipeTarget (prodTarget)
import Poppy.Codegen.CLI (mainWith)

main :: IO ()
main = mainWith [prodTarget] [prodTarget]
