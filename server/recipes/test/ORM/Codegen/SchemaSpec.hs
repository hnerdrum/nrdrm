{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.SchemaSpec
  ( schemaSpec,
  )
where

import ORM.Codegen.Schema
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import Test.Hspec

schemaSpec :: Spec
schemaSpec =
  describe "ORM.Codegen.Schema" $ do
    it "auto-emits {Model}Include when a model has relations and none is declared" $ do
      let parent =
            model
              "Parent"
              [uuid "id" & pk]
              [hasMany "parentKids" "Kid" "parentId"]
          child =
            model
              "Kid"
              [uuid "id" & pk, uuid "parentId"]
              []
          built = schema [] [parent, child] [] []
          incl = head (schemaIncludes built)
      map includeName (schemaIncludes built) `shouldBe` ["ParentInclude"]
      includeRootModel incl `shouldBe` "Parent"
      map includeRelation (includeTree incl) `shouldBe` ["parentKids"]

    it "does not replace an explicit Include for that root with a full-graph Include" $ do
      let names = map includeName (schemaIncludes shelfSchema)
          shelfIncl = head (schemaIncludes shelfSchema)
      take 2 names `shouldBe` ["ShelfInclude", "ShelfGraphInclude"]
      filter (== "ShelfInclude") names `shouldBe` ["ShelfInclude"]
      map includeRelation (includeTree shelfIncl) `shouldBe` ["shelfBooks"]

    it "auto-emits RecipeInclude from relations when the Recipe schema declares none" $ do
      map includeName (schemaIncludes recipeSchema)
        `shouldBe` ["RecipeInclude", "RecipeIngredientInclude"]
