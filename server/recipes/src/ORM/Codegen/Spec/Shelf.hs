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
      schemaModels = [shelfModel, bookModel, chapterModel, sectionModel, tagModel],
      schemaIncludes = [shelfInclude, shelfGraphInclude]
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
        [ hasMany "shelfBooks" "Shelf" "Book" "id" "shelfId",
          hasMany "shelfTags" "Shelf" "Tag" "id" "shelfId"
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
      modelRelations =
        [ hasMany "chapterSections" "Chapter" "Section" "id" "chapterRef"
        ]
    }

sectionModel :: Model
sectionModel =
  Model
    { modelName = "Section",
      modelTable = "test_section",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "chapter_id" (uuid "chapterRef"),
          text "label"
        ],
      modelRelations = []
    }

tagModel :: Model
tagModel =
  Model
    { modelName = "Tag",
      modelTable = "test_tag",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "shelf_id" (uuid "shelfId"),
          text "label"
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

shelfGraphInclude :: ModelInclude
shelfGraphInclude =
  ModelInclude
    { includeName = "ShelfGraphInclude",
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
            },
          IncludeTree
            { includeRelation = "shelfTags",
              includeChildren = []
            }
        ]
    }
