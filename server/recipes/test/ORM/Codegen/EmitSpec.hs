{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitSpec
  ( emitSpec,
  )
where

import Data.List (find)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import ORM.Codegen.Emit.Schema (emitBelongsTo, emitHasMany, emitModelModule)
import ORM.Codegen.IR
  ( JoinKind (..),
    Model (..),
    RelationKind (..),
    RelationSpec (..),
    Schema (..),
    modelName,
    modelRelations,
    relJoin,
    relName,
  )
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import ORM.Codegen.Spec.Widget (widgetModel)
import Test.Hspec

emitSpec :: Spec
emitSpec = do
  describe "ORM.Codegen.Emit.Schema" $ do
    it "emits Widget matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/Widget.hs.golden"
      let actual = emitModelModule "Schema.Widget" widgetSchema widgetModel
      T.strip actual `shouldBe` T.strip expected

    it "includes HasMany in a Shelf model module" $ do
      let actual = emitModelModule "Schema.Shelf" shelfSchema shelfModel
      actual `shouldSatisfy` T.isInfixOf "import ORM.Relation (HasMany (..), JoinType (..))"
      actual `shouldSatisfy` T.isInfixOf "import Schema.Book (BookTable, bookShelfId)"
      actual `shouldSatisfy` T.isInfixOf "    shelfBooks"
      T.strip (emitHasMany shelfSchema shelfBooksRel)
        `shouldSatisfy` (`T.isInfixOf` T.strip actual)

    it "includes BelongsTo in a RecipeIngredient model module" $ do
      let actual =
            emitModelModule "ORM.Schema.RecipeIngredient" recipeSchema recipeIngredientModel
      actual
        `shouldSatisfy` T.isInfixOf "import ORM.Relation (BelongsTo (..), JoinType (..))"
      actual
        `shouldSatisfy` T.isInfixOf "import ORM.Schema.Ingredient (IngredientTable)"
      actual `shouldSatisfy` T.isInfixOf "    riIngredient"
      actual `shouldSatisfy` T.isInfixOf "import ORM.Schema.Unit (Unit)"
      T.strip (emitBelongsTo recipeSchema riIngredientRel)
        `shouldSatisfy` (`T.isInfixOf` T.strip actual)

    it "emits Shelf matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/Shelf.hs.golden"
      let actual = emitModelModule "Schema.Shelf" shelfSchema shelfModel
      T.strip actual `shouldBe` T.strip expected

    it "emits Book matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/Book.hs.golden"
      let actual = emitModelModule "Schema.Book" shelfSchema bookModel
      T.strip actual `shouldBe` T.strip expected

    it "emits Chapter matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/Chapter.hs.golden"
      let actual = emitModelModule "Schema.Chapter" shelfSchema chapterModel
      T.strip actual `shouldBe` T.strip expected

    it "emits Ingredient matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/Ingredient.hs.golden"
      let actual = emitModelModule "ORM.Schema.Ingredient" recipeSchema ingredientModel
      T.strip actual `shouldBe` T.strip expected

    it "emits Recipe matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/Recipe.hs.golden"
      let actual = emitModelModule "ORM.Schema.Recipe" recipeSchema recipeModel
      T.strip actual `shouldBe` T.strip expected

    it "emits RecipeIngredient matching the golden file" $ do
      expected <- T.readFile "test/ORM/Codegen/golden/RecipeIngredient.hs.golden"
      let actual =
            emitModelModule "ORM.Schema.RecipeIngredient" recipeSchema recipeIngredientModel
      T.strip actual `shouldBe` T.strip expected

  describe "ORM.Codegen.Emit.Schema.emitHasMany" $ do
    it "emits shelfBooks" $ do
      T.strip (emitHasMany shelfSchema shelfBooksRel)
        `shouldBe` T.strip expectedShelfBooks
    it "honors InnerJoin" $ do
      let rel = shelfBooksRel {relJoin = JoinInner}
      T.strip (emitHasMany shelfSchema rel)
        `shouldBe` T.strip expectedShelfBooksInner

    it "emits bookChapters" $ do
      T.strip (emitHasMany shelfSchema bookChaptersRel)
        `shouldBe` T.strip expectedBookChapters

  describe "ORM.Codegen.Emit.Schema.emitBelongsTo" $ do
    it "emits riIngredient" $ do
      T.strip (emitBelongsTo recipeSchema riIngredientRel)
        `shouldBe` T.strip expectedRiIngredient

widgetSchema :: Schema
widgetSchema =
  Schema
    { schemaEnums = [],
      schemaModels = [widgetModel],
      schemaIncludes = []
    }

shelfModel :: Model
shelfModel =
  case find ((== "Shelf") . modelName) (schemaModels shelfSchema) of
    Just m -> m
    Nothing -> error "shelfModel: Shelf missing"

shelfBooksRel :: RelationSpec
shelfBooksRel =
  case find ((== "shelfBooks") . relName) (modelRelations shelfModel) of
    Just rel | relKind rel == RelHasMany -> rel
    _ -> error "shelfBooksRel: shelfBooks HasMany missing"

expectedShelfBooks :: T.Text
expectedShelfBooks =
  T.unlines
    [ "shelfBooks :: HasMany ShelfTable BookTable UUID",
      "shelfBooks =",
      "  HasMany",
      "    { localKey = shelfId,",
      "      foreignKey = bookShelfId,",
      "      joinType = LeftJoin",
      "    }"
    ]

expectedShelfBooksInner :: T.Text
expectedShelfBooksInner =
  T.unlines
    [ "shelfBooks :: HasMany ShelfTable BookTable UUID",
      "shelfBooks =",
      "  HasMany",
      "    { localKey = shelfId,",
      "      foreignKey = bookShelfId,",
      "      joinType = InnerJoin",
      "    }"
    ]

bookModel :: Model
bookModel =
  case find ((== "Book") . modelName) (schemaModels shelfSchema) of
    Just m -> m
    Nothing -> error "bookModel: Book missing"

chapterModel :: Model
chapterModel =
  case find ((== "Chapter") . modelName) (schemaModels shelfSchema) of
    Just m -> m
    Nothing -> error "chapterModel: Chapter missing"

bookChaptersRel :: RelationSpec
bookChaptersRel =
  case find ((== "bookChapters") . relName) (modelRelations bookModel) of
    Just rel | relKind rel == RelHasMany -> rel
    _ -> error "bookChaptersRel: bookChapters HasMany missing"

expectedBookChapters :: T.Text
expectedBookChapters =
  T.unlines
    [ "bookChapters :: HasMany BookTable ChapterTable UUID",
      "bookChapters =",
      "  HasMany",
      "    { localKey = bookId,",
      "      foreignKey = chapterBookRef,",
      "      joinType = LeftJoin",
      "    }"
    ]

recipeModel :: Model
recipeModel =
  case find ((== "Recipe") . modelName) (schemaModels recipeSchema) of
    Just m -> m
    Nothing -> error "recipeModel: Recipe missing"

ingredientModel :: Model
ingredientModel =
  case find ((== "Ingredient") . modelName) (schemaModels recipeSchema) of
    Just m -> m
    Nothing -> error "ingredientModel: Ingredient missing"

recipeIngredientModel :: Model
recipeIngredientModel =
  case find ((== "RecipeIngredient") . modelName) (schemaModels recipeSchema) of
    Just m -> m
    Nothing -> error "recipeIngredientModel: RecipeIngredient missing"

riIngredientRel :: RelationSpec
riIngredientRel =
  case find ((== "riIngredient") . relName) (modelRelations recipeIngredientModel) of
    Just rel | relKind rel == RelBelongsTo -> rel
    _ -> error "riIngredientRel: riIngredient BelongsTo missing"

expectedRiIngredient :: T.Text
expectedRiIngredient =
  T.unlines
    [ "riIngredient :: BelongsTo RecipeIngredientTable IngredientTable UUID",
      "riIngredient =",
      "  BelongsTo",
      "    { foreignKey = recipeIngredientIngredientId,",
      "      references = Ingredient.ingredientId,",
      "      joinType = LeftJoin",
      "    }"
    ]