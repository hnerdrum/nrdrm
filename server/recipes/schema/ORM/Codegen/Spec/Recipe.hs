{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.Recipe
  ( recipeSchema,
  )
where

import ORM.Codegen.Schema

recipeSchema :: Schema
recipeSchema =
  schema
    [unitEnum]
    [recipeModel, ingredientModel, recipeIngredientModel]
    [includeGraph "RecipeInclude" "Recipe"]
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
    [ hasMany "recipeIngredients" "RecipeIngredient" "recipeId" & replaceChildren
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
    [belongsTo "riIngredient" "Ingredient" "ingredientId"]
