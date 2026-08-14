{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.Shelf
  ( shelfSchema,
  )
where

import ORM.Codegen.IR

shelfSchema :: Schema
shelfSchema =
  Schema
    { schemaEnums = [],
      schemaModels = [shelfModel, bookModel, chapterModel],
      schemaIncludes = [shelfInclude]
    }

shelfModel :: Model
shelfModel =
  Model
    { modelName = "Shelf",
      modelTable = "test_shelf",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          text "name"
        ],
      modelRelations =
        [ hasMany "shelfBooks" "Shelf" "Book" "id" "shelfId"
        ]
    }

bookModel :: Model
bookModel =
  Model
    { modelName = "Book",
      modelTable = "test_book",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "shelf_id" (uuid "shelfId"),
          text "title"
        ],
      modelRelations =
        [ hasMany "bookChapters" "Book" "Chapter" "id" "bookRef"
        ]
    }

chapterModel :: Model
chapterModel =
  Model
    { modelName = "Chapter",
      modelTable = "test_chapter",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "book_id" (uuid "bookRef"),
          text "heading"
        ],
      modelRelations = []
    }

shelfInclude :: ModelInclude
shelfInclude =
  ModelInclude
    { includeName = "ShelfInclude",
      includeRootModel = "Shelf",
      includeTree =
        [ IncludeTree
            { includeRelation = "shelfBooks",
              includeChildren =
                [ IncludeTree
                    { includeRelation = "bookChapters",
                      includeChildren = []
                    }
                ]
            }
        ]
    }
