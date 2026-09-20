module Main (main) where

import ORM.Codegen.Spec.Recipe (recipeSchema)
import Poppy.Codegen.CLI (generate)

main :: IO ()
main = generate ".orm-gen/ORM" recipeSchema
