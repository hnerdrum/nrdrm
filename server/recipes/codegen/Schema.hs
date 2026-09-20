{-# LANGUAGE OverloadedStrings #-}

module Schema
  ( recipesSchema,
  )
where

import Poppy.Codegen.Schema

recipesSchema :: Schema
recipesSchema =
  schema
    [unitEnum]
    [recipeModel, ingredientModel, recipeIngredientModel]
    [unique_ "RecipeIngredient" ["recipeId", "ingredientId"]]

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
  model
    "Recipe"
    [ uuid "id" & pk & withDefault DefaultUuidV4,
      timestamptz "createdAt" & withDefault DefaultNow,
      timestamptz "updatedAt" & withDefault DefaultNow & updatedAt,
      text "name",
      text "description" & nullable
    ]
    [ hasMany "recipeIngredients" "RecipeIngredient" "recipeId"
    ]

ingredientModel :: Model
ingredientModel =
  model
    "Ingredient"
    [ uuid "id" & pk & withDefault DefaultUuidV4,
      timestamptz "createdAt" & withDefault DefaultNow,
      timestamptz "updatedAt" & withDefault DefaultNow & updatedAt,
      text "name"
    ]
    []

recipeIngredientModel :: Model
recipeIngredientModel =
  model
    "RecipeIngredient"
    [ uuid "id" & pk & withDefault DefaultUuidV4,
      uuid "recipeId",
      uuid "ingredientId",
      int "amount",
      enumField "unit" "Unit"
    ]
    [belongsTo "ingredient" "Ingredient" "ingredientId"]
