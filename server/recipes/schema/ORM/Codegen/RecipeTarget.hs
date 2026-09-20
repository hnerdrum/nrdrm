{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.RecipeTarget
  ( prodTarget,
  )
where

import ORM.Codegen.Spec.Recipe (recipeSchema)
import Poppy.Codegen.Target
  ( ClientConfig (..),
    ClientLayout (..),
    CodegenTarget (..),
    SchemaEmit (..),
    SchemaLayout (..),
    TargetSchema (..),
  )

prodTarget :: CodegenTarget
prodTarget =
  CodegenTarget
    { ctSchemas = [TargetSchema recipeSchema True EmitAll],
      ctLayout = SchemaLayout "ORM.Schema." ".orm-gen/ORM/Schema/",
      ctClients =
        DeriveClients
          ClientLayout
            { clModulePrefix = "ORM.Client.",
              clOutputDir = ".orm-gen/ORM/Client/",
              clGolden = False
            }
    }
