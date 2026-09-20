module Main (main) where

import Poppy.Codegen.CLI (generate)
import Schema (recipesSchema)

main :: IO ()
main = generate ".poppy/Schema" recipesSchema
