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
    [ "{-# LANGUAGE TypeApplications #-}",
      "",
      "module Schema.Client.Shelf",
      "  ( findAllWith,",
      "    findManyWith,",
      "    findUniqueWith,",
      "    findUniqueOrErrorWith,",
      "    findAllWithConn,",
      "    findManyWithConn,",
      "    findUniqueWithConn,",
      "    findUniqueOrErrorWithConn,",
      "    withBooks,",
      "    noInclude",
      "  )",
      "where",
      "",
      "import Data.Pool (Pool)",
      "import Data.UUID (UUID)",
      "import Database.PostgreSQL.Simple (Connection)",
      "import ORM.Errors (ORMError)",
      "import qualified ORM.Include as Include",
      "import ORM.Query (QueryBuilder)",
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
      "findAllWith :: Pool Connection -> ShelfInclude -> IO [ShelfWithBooks]",
      "findAllWith = Include.findAllWith @ShelfTable",
      "",
      "findAllWithConn :: Connection -> ShelfInclude -> IO [ShelfWithBooks]",
      "findAllWithConn = Include.findAllWithConn @ShelfTable",
      "",
      "findManyWith ::",
      "  Pool Connection ->",
      "  ShelfInclude ->",
      "  (QueryBuilder ShelfTable -> QueryBuilder ShelfTable) ->",
      "  IO [ShelfWithBooks]",
      "findManyWith = Include.findManyWith @ShelfTable",
      "",
      "findManyWithConn ::",
      "  Connection ->",
      "  ShelfInclude ->",
      "  (QueryBuilder ShelfTable -> QueryBuilder ShelfTable) ->",
      "  IO [ShelfWithBooks]",
      "findManyWithConn = Include.findManyWithConn @ShelfTable",
      "",
      "findUniqueWith :: Pool Connection -> ShelfInclude -> UUID -> IO (Maybe ShelfWithBooks)",
      "findUniqueWith = Include.findUniqueWith @ShelfTable",
      "",
      "findUniqueWithConn :: Connection -> ShelfInclude -> UUID -> IO (Maybe ShelfWithBooks)",
      "findUniqueWithConn = Include.findUniqueWithConn @ShelfTable",
      "",
      "findUniqueOrErrorWith :: Pool Connection -> ShelfInclude -> UUID -> IO (Either ORMError ShelfWithBooks)",
      "findUniqueOrErrorWith = Include.findUniqueOrErrorWith @ShelfTable",
      "",
      "findUniqueOrErrorWithConn :: Connection -> ShelfInclude -> UUID -> IO (Either ORMError ShelfWithBooks)",
      "findUniqueOrErrorWithConn = Include.findUniqueOrErrorWithConn @ShelfTable"
    ]
