{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Target
  ( GenOutput (..),
    CodegenTarget (..),
    TargetSchema (..),
    SchemaLayout (..),
    ClientConfig (..),
    ClientLayout (..),
    SchemaEmit (..),
    testTarget,
    targetOutputs,
    targetSchemas,
  )
where

import Data.List (find, nub)
import Data.Maybe (isNothing)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.Emit.Client
  ( emitIncludeReadClientModule,
    emitSimpleClientModule,
    emitWriteClientModule,
  )
import ORM.Codegen.Emit.Include (emitIncludeModule)
import ORM.Codegen.Emit.Schema (emitEnumModule, emitModelModule)
import ORM.Codegen.IR
  ( EnumSpec (..),
    Model (..),
    ModelInclude (..),
    RelationSpec (..),
    Schema (..),
    enumImport,
    enumName,
    includeName,
    includeRelation,
    includeRootModel,
    includeTree,
    modelName,
    modelRelations,
    relName,
    relReplaceChildren,
    relToModel,
    schemaEnums,
    schemaIncludes,
    schemaModels,
  )
import ORM.Codegen.Spec.Shelf (shelfSchema)
import ORM.Codegen.Spec.ShelfDeep (shelfDeepSchema)
import ORM.Codegen.Spec.Widget (widgetSchema)
import System.FilePath ((</>))

data GenOutput = GenOutput
  { outputPath :: FilePath,
    outputText :: Text
  }

data SchemaLayout = SchemaLayout
  { slModulePrefix :: Text,
    slOutputDir :: FilePath
  }

data ClientLayout = ClientLayout
  { clModulePrefix :: Text,
    clOutputDir :: FilePath,
    clGolden :: Bool
  }

data ClientConfig
  = NoClients
  | DeriveClients ClientLayout

data TargetSchema = TargetSchema
  { tsSchema :: Schema,
    tsGolden :: Bool,
    tsEmit :: SchemaEmit
  }

data SchemaEmit
  = EmitAll
  | EmitIncludesOnly

data CodegenTarget = CodegenTarget
  { ctSchemas :: [TargetSchema],
    ctLayout :: SchemaLayout,
    ctClients :: ClientConfig
  }

testTarget :: CodegenTarget
testTarget =
  CodegenTarget
    { ctSchemas =
        [ TargetSchema widgetSchema True EmitAll,
          TargetSchema shelfSchema True EmitAll,
          TargetSchema shelfDeepSchema False EmitIncludesOnly
        ],
      ctLayout = SchemaLayout "Schema." "test/Schema/",
      ctClients = NoClients
    }

targetSchemas :: [CodegenTarget] -> [Schema]
targetSchemas targets = map (.tsSchema) (concatMap (.ctSchemas) targets)

targetOutputs :: CodegenTarget -> [GenOutput]
targetOutputs target =
  concatMap (schemaOutputs target) target.ctSchemas

schemaOutputs :: CodegenTarget -> TargetSchema -> [GenOutput]
schemaOutputs target TargetSchema {tsSchema = schema, tsGolden = golden, tsEmit = emit} =
  enumOutputs target golden schema emit
    ++ modelOutputs target golden schema emit
    ++ includeOutputs target golden schema emit
    ++ clientOutputs target schema emit

enumOutputs :: CodegenTarget -> Bool -> Schema -> SchemaEmit -> [GenOutput]
enumOutputs _ _ _ EmitIncludesOnly = []
enumOutputs target golden schema EmitAll =
  concat
    [ enumOutput target golden schema enum
      | enum <- schemaEnums schema,
        isNothing (enumImport enum)
    ]

enumOutput :: CodegenTarget -> Bool -> Schema -> EnumSpec -> [GenOutput]
enumOutput target golden _schema enum =
  let layout = target.ctLayout
      name = enumName enum
      moduleName = layout.slModulePrefix <> name
      path = layout.slOutputDir </> T.unpack name <> ".hs"
      text = emitEnumModule moduleName enum
   in withGolden golden (T.unpack name <> ".hs") path text

modelOutputs :: CodegenTarget -> Bool -> Schema -> SchemaEmit -> [GenOutput]
modelOutputs _ _ _ EmitIncludesOnly = []
modelOutputs target golden schema EmitAll =
  concatMap (modelOutput target golden schema) (schemaModels schema)

modelOutput :: CodegenTarget -> Bool -> Schema -> Model -> [GenOutput]
modelOutput target golden schema model =
  let layout = target.ctLayout
      name = modelName model
      moduleName = layout.slModulePrefix <> name
      path = layout.slOutputDir </> T.unpack name <> ".hs"
      text = emitModelModule moduleName schema model
   in withGolden golden (T.unpack name <> ".hs") path text

includeOutputs :: CodegenTarget -> Bool -> Schema -> SchemaEmit -> [GenOutput]
includeOutputs target golden schema _ =
  concatMap (includeOutput target golden schema) (schemaIncludes schema)

includeOutput :: CodegenTarget -> Bool -> Schema -> ModelInclude -> [GenOutput]
includeOutput target golden schema incl =
  let layout = target.ctLayout
      name = includeName incl
      moduleName = layout.slModulePrefix <> name
      path = layout.slOutputDir </> T.unpack name <> ".hs"
      text = emitIncludeModule moduleName schema incl
   in withGolden golden (T.unpack name <> ".hs") path text

clientOutputs :: CodegenTarget -> Schema -> SchemaEmit -> [GenOutput]
clientOutputs _ _ EmitIncludesOnly = []
clientOutputs target schema EmitAll =
  case target.ctClients of
    NoClients -> []
    DeriveClients layout ->
      simpleClientOutputs layout schema
        ++ includeClientOutputs layout schema

simpleClientOutputs :: ClientLayout -> Schema -> [GenOutput]
simpleClientOutputs layout schema =
  concatMap (simpleClientOutput layout) (simpleClientModels schema)

simpleClientOutput :: ClientLayout -> Model -> [GenOutput]
simpleClientOutput layout model =
  let name = modelName model
      moduleName = layout.clModulePrefix <> name
      path = layout.clOutputDir </> T.unpack name <> ".hs"
      text = emitSimpleClientModule moduleName model
   in withGolden layout.clGolden (T.unpack name <> "Client.hs") path text

includeClientOutputs :: ClientLayout -> Schema -> [GenOutput]
includeClientOutputs layout schema =
  concatMap (includeClientOutput layout schema) (schemaIncludes schema)

includeClientOutput :: ClientLayout -> Schema -> ModelInclude -> [GenOutput]
includeClientOutput layout schema incl =
  let rootName = includeRootModel incl
      root = lookupModel schema rootName
      moduleName = layout.clModulePrefix <> rootName
      path = layout.clOutputDir </> T.unpack rootName <> ".hs"
      text =
        if includeUsesReplaceChildren root incl
          then emitWriteClientModule moduleName schema incl
          else emitIncludeReadClientModule moduleName schema incl
   in withGolden layout.clGolden (T.unpack rootName <> "Client.hs") path text

simpleClientModels :: Schema -> [Model]
simpleClientModels schema =
  let skip = includeRootModels schema ++ replaceChildTargetModels schema
   in filter (\model -> modelName model `notElem` skip) (schemaModels schema)

includeRootModels :: Schema -> [Text]
includeRootModels = map includeRootModel . schemaIncludes

replaceChildTargetModels :: Schema -> [Text]
replaceChildTargetModels schema =
  nub
    [ relToModel rel
      | incl <- schemaIncludes schema,
        let root = lookupModel schema (includeRootModel incl),
        edge <- includeTree incl,
        let rel = lookupRelation root (includeRelation edge),
        relReplaceChildren rel
    ]

includeUsesReplaceChildren :: Model -> ModelInclude -> Bool
includeUsesReplaceChildren root incl =
  any
    (relReplaceChildren . lookupRelation root . includeRelation)
    (includeTree incl)

withGolden :: Bool -> FilePath -> FilePath -> Text -> [GenOutput]
withGolden golden goldenFile path text =
  gen path text
    : ([genGolden goldenFile text | golden])

gen :: FilePath -> Text -> GenOutput
gen path text = GenOutput {outputPath = path, outputText = text}

genGolden :: FilePath -> Text -> GenOutput
genGolden file text =
  GenOutput
    { outputPath = "test/ORM/Codegen/golden/" <> file <> ".golden",
      outputText = text
    }

lookupModel :: Schema -> Text -> Model
lookupModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just model -> model
    Nothing ->
      error $
        "ORM.Codegen.Target: missing model "
          <> T.unpack name

lookupRelation :: Model -> Text -> RelationSpec
lookupRelation model relationName =
  case find ((== relationName) . relName) (modelRelations model) of
    Just rel -> rel
    Nothing ->
      error $
        "ORM.Codegen.Target: missing relation "
          <> T.unpack relationName
          <> " on "
          <> T.unpack (modelName model)
