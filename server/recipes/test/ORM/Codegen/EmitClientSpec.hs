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
      "{-# LANGUAGE FlexibleInstances #-}",
      "{-# LANGUAGE MultiParamTypeClasses #-}",
      "{-# LANGUAGE RecordWildCards #-}",
      "{-# LANGUAGE TypeApplications #-}",
      "{-# LANGUAGE TypeFamilies #-}",
      "",
      "module Schema.Client.Shelf",
      "  ( findMany,",
      "    findUnique,",
      "    findUniqueOrFail,",
      "    withBooks,",
      "    noInclude,",
      "    WithBooks (..),",
      "    NoInclude (..),",
      "    ResolveInclude,",
      "    ShelfQuery (..)",
      "  )",
      "where",
      "",
      "import Data.UUID (UUID)",
      "import ORM.Db (Db)",
      "import ORM.Errors (ORMError)",
      "import qualified ORM.Include as Include",
      "import qualified ORM.Operations as Ops",
      "import ORM.Query (QueryBuilder, applyQueryModifiers)",
      "import ORM.Where (Where)",
      "import Schema.Shelf (ShelfTable, ShelfRow)",
      "import Schema.ShelfInclude ( ShelfInclude (..), BookInclude (..), ShelfWithBooks (..), BookWithChapters (..), WithBooks (..), NoInclude (..), ResolveInclude, unwrapWithBooks)",
      "",
      "withBooks :: WithBooks",
      "withBooks =",
      "  WithBooks ShelfInclude {books = Just (BookInclude {chapters = True})}",
      "",
      "noInclude :: NoInclude",
      "noInclude = NoInclude ShelfInclude {books = Nothing}",
      "",
      "data ShelfQuery preset = ShelfQuery",
      "  { where_ :: Maybe (Where ShelfTable)",
      "  , orderBy_ :: Maybe (QueryBuilder ShelfTable -> QueryBuilder ShelfTable)",
      "  , limit_ :: Maybe Int",
      "  , offset_ :: Maybe Int",
      "  }",
      "",
      "type instance ResolveInclude (ShelfQuery WithBooks) = ShelfWithBooks",
      "type instance ResolveInclude (ShelfQuery NoInclude) = ShelfRow",
      "",
      "class FindManyShelf preset where",
      "  findMany :: preset -> Db [ResolveInclude preset]",
      "",
      "instance FindManyShelf WithBooks where",
      "  findMany preset =",
      "    Include.findMany @ShelfTable (unwrapWithBooks preset) Prelude.id",
      "",
      "instance FindManyShelf NoInclude where",
      "  findMany _ =",
      "    Ops.findMany @ShelfTable @ShelfRow Prelude.id",
      "",
      "instance FindManyShelf (ShelfQuery WithBooks) where",
      "  findMany ShelfQuery {..} =",
      "    Include.findMany @ShelfTable (unwrapWithBooks withBooks) (applyQueryModifiers where_ orderBy_ limit_ offset_)",
      "",
      "instance FindManyShelf (ShelfQuery NoInclude) where",
      "  findMany ShelfQuery {..} =",
      "    Ops.findMany @ShelfTable @ShelfRow (applyQueryModifiers where_ orderBy_ limit_ offset_)",
      "",
      "class FindUniqueShelf preset where",
      "  findUnique :: preset -> UUID -> Db (Maybe (ResolveInclude preset))",
      "",
      "",
      "instance FindUniqueShelf WithBooks where",
      "  findUnique preset =",
      "    Include.findUnique @ShelfTable (unwrapWithBooks preset)",
      "",
      "instance FindUniqueShelf NoInclude where",
      "  findUnique _ =",
      "    Ops.findUnique @ShelfTable @ShelfRow",
      "",
      "class FindUniqueOrFailShelf preset where",
      "  findUniqueOrFail :: preset -> UUID -> Db (Either ORMError (ResolveInclude preset))",
      "",
      "",
      "instance FindUniqueOrFailShelf WithBooks where",
      "  findUniqueOrFail preset =",
      "    Include.findUniqueOrFail @ShelfTable (unwrapWithBooks preset)",
      "",
      "instance FindUniqueOrFailShelf NoInclude where",
      "  findUniqueOrFail _ =",
      "    Ops.findUniqueOrFail @ShelfTable @ShelfRow"
    ]
