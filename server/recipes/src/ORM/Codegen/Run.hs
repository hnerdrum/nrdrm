{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Run
  ( GenOutput (..),
    allOutputs,
    checkOutputs,
    writeOutputs,
    codegenSchemas,
  )
where

import Data.List (find)
import Data.Maybe (isNothing)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import ORM.Codegen.Emit.Client
  ( emitSimpleClientModule,
    emitWriteClientModule,
  )
import ORM.Codegen.Emit.Include (emitIncludeModule)
import ORM.Codegen.Emit.Schema (emitEnumModule, emitModelModule)
import ORM.Codegen.IR
  ( EnumSpec (..),
    Model (..),
    Schema (..),
    enumImport,
    enumName,
    modelName,
    schemaEnums,
    schemaIncludes,
    schemaModels,
  )
import ORM.Codegen.Spec.Recipe (recipeSchema)
import ORM.Codegen.Spec.Shelf (shelfSchema)
import ORM.Codegen.Spec.ShelfDeep (shelfDeepSchema)
import ORM.Codegen.Spec.Widget (widgetModel)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.FilePath (takeDirectory, (</>))

codegenSchemas :: [Schema]
codegenSchemas = [widgetSchema, shelfSchema, recipeSchema]

data GenOutput = GenOutput
  { outputPath :: FilePath,
    outputText :: Text
  }

allOutputs :: [GenOutput]
allOutputs = shelfTestOutputs ++ shelfDeepTestOutputs ++ recipeProdOutputs

writeOutputs :: FilePath -> IO ()
writeOutputs root = mapM_ (writeOutput root) allOutputs

checkOutputs :: FilePath -> IO [FilePath]
checkOutputs root = filterMismatches root allOutputs

writeOutput :: FilePath -> GenOutput -> IO ()
writeOutput root GenOutput {outputPath = path, outputText = text} = do
  let fullPath = root </> path
  createDirectoryIfMissing True (takeDirectory fullPath)
  TIO.writeFile fullPath text

filterMismatches :: FilePath -> [GenOutput] -> IO [FilePath]
filterMismatches root = foldr go (pure [])
  where
    go GenOutput {outputPath = path, outputText = expected} acc = do
      mismatches <- acc
      let fullPath = root </> path
      exists <- doesFileExist fullPath
      if not exists
        then pure (path : mismatches)
        else do
          actual <- TIO.readFile fullPath
          pure (if stripText actual == stripText expected then mismatches else path : mismatches)

stripText :: Text -> Text
stripText = T.strip

shelfTestOutputs :: [GenOutput]
shelfTestOutputs =
  [ gen "test/Schema/Widget.hs" $
      emitModelModule "Schema.Widget" widgetSchema widgetModel,
    genGolden "Widget.hs" $
      emitModelModule "Schema.Widget" widgetSchema widgetModel,
    gen "test/Schema/Shelf.hs" $
      emitModelModule "Schema.Shelf" shelfSchema shelfModel,
    genGolden "Shelf.hs" $
      emitModelModule "Schema.Shelf" shelfSchema shelfModel,
    gen "test/Schema/Book.hs" $
      emitModelModule "Schema.Book" shelfSchema bookModel,
    genGolden "Book.hs" $
      emitModelModule "Schema.Book" shelfSchema bookModel,
    gen "test/Schema/Chapter.hs" $
      emitModelModule "Schema.Chapter" shelfSchema chapterModel,
    genGolden "Chapter.hs" $
      emitModelModule "Schema.Chapter" shelfSchema chapterModel,
    gen "test/Schema/Section.hs" $
      emitModelModule "Schema.Section" shelfSchema sectionModel,
    genGolden "Section.hs" $
      emitModelModule "Schema.Section" shelfSchema sectionModel,
    gen "test/Schema/ShelfInclude.hs" $
      emitIncludeModule "Schema.ShelfInclude" shelfSchema shelfInclude,
    genGolden "ShelfInclude.hs" $
      emitIncludeModule "Schema.ShelfInclude" shelfSchema shelfInclude
  ]
  where
    shelfInclude = head (schemaIncludes shelfSchema)

shelfDeepTestOutputs :: [GenOutput]
shelfDeepTestOutputs =
  [ gen "test/Schema/ShelfDeepInclude.hs" $
      emitIncludeModule "Schema.ShelfDeepInclude" shelfDeepSchema shelfDeepInclude
  ]
  where
    shelfDeepInclude = head (schemaIncludes shelfDeepSchema)

recipeProdOutputs :: [GenOutput]
recipeProdOutputs =
  recipeInlineEnumOutputs
    ++ [ gen "src/ORM/Schema/Ingredient.hs" $
           emitModelModule "ORM.Schema.Ingredient" recipeSchema ingredientModel,
         genGolden "Ingredient.hs" $
           emitModelModule "ORM.Schema.Ingredient" recipeSchema ingredientModel,
         gen "src/ORM/Schema/Recipe.hs" $
           emitModelModule "ORM.Schema.Recipe" recipeSchema recipeModel,
         genGolden "Recipe.hs" $
           emitModelModule "ORM.Schema.Recipe" recipeSchema recipeModel,
         gen "src/ORM/Schema/RecipeIngredient.hs" $
           emitModelModule "ORM.Schema.RecipeIngredient" recipeSchema recipeIngredientModel,
         genGolden "RecipeIngredient.hs" $
           emitModelModule "ORM.Schema.RecipeIngredient" recipeSchema recipeIngredientModel,
         gen "src/ORM/Schema/RecipeInclude.hs" $
           emitIncludeModule "ORM.Schema.RecipeInclude" recipeSchema recipeInclude,
         genGolden "RecipeInclude.hs" $
           emitIncludeModule "ORM.Schema.RecipeInclude" recipeSchema recipeInclude,
         gen "src/ORM/Client/Ingredient.hs" $
           emitSimpleClientModule "ORM.Client.Ingredient" ingredientModel,
         genGolden "IngredientClient.hs" $
           emitSimpleClientModule "ORM.Client.Ingredient" ingredientModel,
         gen "src/ORM/Client/Recipe.hs" $
           emitWriteClientModule "ORM.Client.Recipe" recipeSchema recipeInclude,
         genGolden "RecipeClient.hs" $
           emitWriteClientModule "ORM.Client.Recipe" recipeSchema recipeInclude
       ]
  where
    recipeInclude = head (schemaIncludes recipeSchema)

recipeInlineEnumOutputs :: [GenOutput]
recipeInlineEnumOutputs =
  concat
    [ [ gen ("src/ORM/Schema/" <> T.unpack (enumName e) <> ".hs") $
          emitEnumModule ("ORM.Schema." <> enumName e) e,
        genGolden (T.unpack (enumName e) <> ".hs") $
          emitEnumModule ("ORM.Schema." <> enumName e) e
      ]
      | e <- schemaEnums recipeSchema,
        isNothing (enumImport e)
    ]

gen :: FilePath -> Text -> GenOutput
gen path text = GenOutput {outputPath = path, outputText = text}

genGolden :: FilePath -> Text -> GenOutput
genGolden file text =
  GenOutput
    { outputPath = "test/ORM/Codegen/golden/" <> file <> ".golden",
      outputText = text
    }

widgetSchema :: Schema
widgetSchema =
  Schema
    { schemaEnums = [],
      schemaModels = [widgetModel],
      schemaIncludes = []
    }

shelfModel :: Model
shelfModel = requireModel shelfSchema "Shelf"

bookModel :: Model
bookModel = requireModel shelfSchema "Book"

chapterModel :: Model
chapterModel = requireModel shelfSchema "Chapter"

sectionModel :: Model
sectionModel = requireModel shelfSchema "Section"

ingredientModel :: Model
ingredientModel = requireModel recipeSchema "Ingredient"

recipeModel :: Model
recipeModel = requireModel recipeSchema "Recipe"

recipeIngredientModel :: Model
recipeIngredientModel = requireModel recipeSchema "RecipeIngredient"

requireModel :: Schema -> Text -> Model
requireModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just model -> model
    Nothing -> error $ "ORM.Codegen.Run: missing model " <> show name
