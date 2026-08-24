{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.ShelfDeep
  ( shelfDeepSchema,
  )
where

import ORM.Codegen.IR (Schema (..))
import ORM.Codegen.Schema (include, schema, tree)
import ORM.Codegen.Spec.Shelf (shelfSchema)

shelfDeepSchema :: Schema
shelfDeepSchema =
  schema
    (schemaEnums shelfSchema)
    (schemaModels shelfSchema)
    [ include
        "ShelfDeepInclude"
        "Shelf"
        [ tree
            "shelfBooks"
            [tree "bookChapters" [tree "chapterSections" []]]
        ]
    ]
    (schemaUniques shelfSchema)
