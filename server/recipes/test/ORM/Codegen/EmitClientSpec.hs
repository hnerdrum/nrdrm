{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitClientSpec
  ( emitClientSpec,
  )
where

import Data.List (find)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import ORM.Codegen.Emit.Client
  ( emitIncludeReadClientModule,
    emitSimpleClientModule,
    emitWriteClientModule,
  )
import ORM.Codegen.IR
  ( Model (..),
    Schema (..),
    modelName,
    schemaIncludes,
    schemaModels,
  )
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import Test.Hspec

emitClientSpec :: Spec
emitClientSpec =
  describe "ORM.Codegen.Emit.Client" $ do
    it "emits Ingredient Client matching the golden file" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/IngredientClient.hs.golden"
      let actual = emitSimpleClientModule "ORM.Client.Ingredient" ingredientModel
      T.strip actual `shouldBe` T.strip expected

    it "emits Recipe Client matching the golden file" $ do
      expected <- TIO.readFile "test/ORM/Codegen/golden/RecipeClient.hs.golden"
      let incl = head (schemaIncludes recipeSchema)
          actual = emitWriteClientModule "ORM.Client.Recipe" recipeSchema incl
      T.strip actual `shouldBe` T.strip expected

    it "emits Shelf read Client with include helpers" $ do
      let incl = head (schemaIncludes shelfSchema)
          actual = emitIncludeReadClientModule "Schema.Client.Shelf" shelfSchema incl
      T.strip actual `shouldBe` T.strip expectedShelfReadClient

ingredientModel :: Model
ingredientModel =
  case find ((== "Ingredient") . modelName) (schemaModels recipeSchema) of
    Just m -> m
    Nothing -> error "ingredientModel: Ingredient missing"

expectedShelfReadClient :: T.Text
expectedShelfReadClient =
  T.unlines
    [ "{-# LANGUAGE FlexibleContexts #-}",
      "{-# LANGUAGE MultiParamTypeClasses #-}",
      "{-# LANGUAGE RecordWildCards #-}",
      "{-# LANGUAGE TypeApplications #-}",
      "",
      "module Schema.Client.Shelf",
      "  ( findMany,",
      "    findUnique,",
      "    findUniqueOrFail,",
      "    withBooks,",
      "    noInclude,",
      "    ShelfQuery (..),",
      "  )",
      "where",
      "",
      "import Data.UUID (UUID)",
      "import ORM.Db (Db)",
      "import ORM.Errors (ORMError)",
      "import qualified ORM.Include as Include",
      "import ORM.Query (QueryBuilder, applyQueryModifiers)",
      "import Schema.Shelf (ShelfTable)",
      "import Schema.ShelfInclude ( ShelfInclude (..), BookInclude (..), ShelfWithBooks (..))",
      "",
      "withBooks :: ShelfInclude",
      "withBooks =",
      "  ShelfInclude {books = Just (BookInclude {chapters = True})}",
      "",
      "noInclude :: ShelfInclude",
      "noInclude = ShelfInclude {books = Nothing}",
      "",
      "data ShelfQuery = ShelfQuery",
      "  { include :: ShelfInclude",
      "  , where_ :: Maybe (QueryBuilder ShelfTable -> QueryBuilder ShelfTable)",
      "  , orderBy_ :: Maybe (QueryBuilder ShelfTable -> QueryBuilder ShelfTable)",
      "  , limit_ :: Maybe Int",
      "  , offset_ :: Maybe Int",
      "  }",
      "",
      "class FindManyShelf a where",
      "  findMany :: a -> Db [ShelfWithBooks]",
      "",
      "instance FindManyShelf ShelfInclude where",
      "  findMany include =",
      "    findMany",
      "      ShelfQuery",
      "        { include = include,",
      "          where_ = Nothing,",
      "          orderBy_ = Nothing,",
      "          limit_ = Nothing,",
      "          offset_ = Nothing",
      "        }",
      "",
      "instance FindManyShelf ShelfQuery where",
      "  findMany ShelfQuery {..} =",
      "    Include.findMany @ShelfTable include (applyQueryModifiers where_ orderBy_ limit_ offset_)",
      "",
      "findUnique :: ShelfInclude -> UUID -> Db (Maybe ShelfWithBooks)",
      "findUnique = Include.findUnique @ShelfTable",
      "",
      "findUniqueOrFail :: ShelfInclude -> UUID -> Db (Either ORMError ShelfWithBooks)",
      "findUniqueOrFail = Include.findUniqueOrFail @ShelfTable"
    ]
