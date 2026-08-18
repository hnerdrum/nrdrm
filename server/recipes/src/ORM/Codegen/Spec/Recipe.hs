{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.Recipe
  ( recipeSchema,
  )
where

import ORM.Codegen.IR

recipeSchema :: Schema
recipeSchema =
  Schema
    { schemaEnums = [unitEnum],
      schemaModels = [recipeModel, ingredientModel, recipeIngredientModel],
      schemaIncludes = [recipeInclude],
      schemaUniques = [unique_ "RecipeIngredient" ["recipeId", "ingredientId"]]
    }

unitEnum :: EnumSpec
unitEnum =
  enum_
    "Unit"
    [ variantMap "G" "g",
      variantMap "Ml" "ml",
      variantMap "Tsp" "tsp",
      variantMap "Tbsp" "tbsp",
      variantMap "Qty" "qty"
    ]

recipeModel :: Model
recipeModel =
  Model
    { modelName = "Recipe",
      modelTable = "recipe",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "created_at" (withDefault DefaultNow (timestamptz "createdAt")),
          updatedAt (column "updated_at" (withDefault DefaultNow (timestamptz "updatedAt"))),
          text "name",
          nullable (text "description")
        ],
      modelRelations =
        [ replaceChildren $
            hasMany "recipeIngredients" "Recipe" "RecipeIngredient" "id" "recipeId"
        ]
    }

ingredientModel :: Model
ingredientModel =
  Model
    { modelName = "Ingredient",
      modelTable = "ingredient",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "created_at" (withDefault DefaultNow (timestamptz "createdAt")),
          updatedAt (column "updated_at" (withDefault DefaultNow (timestamptz "updatedAt"))),
          text "name"
        ],
      modelRelations = []
    }

recipeIngredientModel :: Model
recipeIngredientModel =
  Model
    { modelName = "RecipeIngredient",
      modelTable = "recipe_ingredient",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "recipe_id" (uuid "recipeId"),
          column "ingredient_id" (uuid "ingredientId"),
          int "amount",
          enumField "unit" "Unit"
        ],
      modelRelations =
        [ belongsTo "riIngredient" "RecipeIngredient" "Ingredient" "ingredientId" "id"
        ]
    }

recipeInclude :: ModelInclude
recipeInclude =
  ModelInclude
    { includeName = "RecipeInclude",
      includeRootModel = "Recipe",
      includeTree =
        [ IncludeTree
            { includeRelation = "recipeIngredients",
              includeChildren =
                [ IncludeTree
                    { includeRelation = "riIngredient",
                      includeChildren = []
                    }
                ]
            }
        ]
    }
