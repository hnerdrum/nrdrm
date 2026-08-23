{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.ShelfDeep
  ( shelfDeepSchema,
  )
where

import ORM.Codegen.IR
import ORM.Codegen.Spec.Shelf (shelfSchema)

shelfDeepSchema :: Schema
shelfDeepSchema =
  shelfSchema
    { schemaIncludes = [shelfDeepInclude]
    }

shelfDeepInclude :: ModelInclude
shelfDeepInclude =
  ModelInclude
    { includeName = "ShelfDeepInclude",
      includeRootModel = "Shelf",
      includeTree =
        [ IncludeTree
            { includeRelation = "shelfBooks",
              includeChildren =
                [ IncludeTree
                    { includeRelation = "bookChapters",
                      includeChildren =
                        [ IncludeTree
                            { includeRelation = "chapterSections",
                              includeChildren = []
                            }
                        ]
                    }
                ]
            }
        ]
    }
