{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.Client
  ( emitSimpleClientModule,
    emitIncludeReadClientModule,
    emitWriteClientModule,
  )
where

import Data.Char (toLower, toUpper)
import Data.List (find)
import Data.Maybe (isNothing)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.IR

emitSimpleClientModule :: Text -> Model -> Text
emitSimpleClientModule moduleName model =
  T.unlines
    [ "{-# LANGUAGE TypeApplications #-}",
      "",
      "module " <> moduleName,
      emitSimpleExports,
      "where",
      "",
      "import Data.Pool (Pool)",
      "import Data.UUID (UUID)",
      "import Database.PostgreSQL.Simple (Connection)",
      "import ORM.Errors (ORMError)",
      "import qualified ORM.Insert as Insert",
      "import qualified ORM.Operations as Ops",
      "import "
        <> schemaModule moduleName model
        <> " ("
        <> createTypeName model
        <> ", "
        <> rowTypeName model
        <> ", "
        <> tableTypeName model
        <> ", "
        <> updateTypeName model
        <> ")",
      "import qualified ORM.Update as Update",
      "",
      emitCreateFn model,
      "",
      emitCreateConnFn model,
      "",
      emitUpdateFn model,
      "",
      emitUpdateConnFn model,
      "",
      emitFindAllFn model,
      "",
      emitFindAllConnFn model,
      "",
      emitFindUniqueFn model,
      "",
      emitFindUniqueConnFn model,
      "",
      emitFindUniqueOrErrorFn model,
      "",
      emitFindUniqueOrErrorConnFn model,
      "",
      emitDeleteFn model,
      "",
      emitDeleteByIdConnFn model
    ]

emitIncludeReadClientModule :: Text -> Schema -> ModelInclude -> Text
emitIncludeReadClientModule moduleName schema incl =
  T.unlines
    ( [ "{-# LANGUAGE TypeApplications #-}",
        "",
        "module " <> moduleName
      ]
        ++ exportLinesFromItems (includeReadExportItems schema incl)
        ++ ["where", ""]
        ++ includeReadImportLines moduleName schema incl
    )
    <> "\n"
    <> intercalateSections (emitIncludeReadDefinitions schema incl)

emitWriteClientModule :: Text -> Schema -> ModelInclude -> Text
emitWriteClientModule moduleName schema incl =
  T.unlines
    ( [ "{-# LANGUAGE DuplicateRecordFields #-}",
        "{-# LANGUAGE OverloadedRecordDot #-}",
        "{-# LANGUAGE TypeApplications #-}",
        "",
        "module " <> moduleName
      ]
        ++ exportLinesFromItems
          ( includeReadFunctionExportItems
              ++ [ "create,",
                   "createConn,",
                   "update,",
                   "updateConn,",
                   "deleteById,",
                   "deleteByIdConn,",
                   writeCreateTypeName root <> " (..),",
                   writeUpdateTypeName root <> " (..),",
                   nestedCreateTypeName child <> " (..),"
                 ]
              ++ includeReadPresetExportItems schema incl
          )
        ++ ["where", ""]
        ++ [ "import Control.Monad (forM_)",
             "import Data.Pool (Pool)",
             "import Data.Time (UTCTime, getCurrentTime)",
             "import Data.UUID (UUID)",
             "import qualified Data.UUID.V4 as V4",
             "import Database.PostgreSQL.Simple (Connection)",
             "import Database.PostgreSQL.Simple.ToField (toField)",
             "import ORM.Core (fieldColumn)",
             "import qualified ORM.Delete as Delete",
             "import ORM.Errors (ORMError)",
             "import qualified ORM.Include as Include",
             "import qualified ORM.Insert as Insert",
             "import "
               <> schemaModule moduleName root
               <> " ( "
               <> createTypeName root
               <> " (..), "
               <> rowTypeName root
               <> ", "
               <> tableTypeName root
               <> ", "
               <> updateTypeName root
               <> " (..))",
             includeModuleImportLine moduleName schema incl,
             "import "
               <> schemaModule moduleName child
               <> " ( "
               <> createTypeName child
               <> " (..), "
               <> tableTypeName child
               <> ", "
               <> wipeField
               <> ")",
             "import ORM.Transaction (transaction)",
             "import qualified ORM.Operations as Ops",
             "import ORM.Query (QueryBuilder)",
             "import qualified ORM.Update as Update"
           ]
        ++ nestedEnumImports schema child
    )
    <> "\n"
    <> intercalateSections
      ( [ emitWriteCreateType root child rel,
          emitWriteUpdateType root child rel,
          emitNestedToChildCreate child rel,
          applyUpdatedAtHelper root
        ]
          ++ emitIncludeReadDefinitions schema incl
          ++ [ emitWriteCreate root incl child rel,
               emitWriteUpdate root incl child rel wipeField,
               emitDeleteFn root,
               emitDeleteByIdConnFn root
             ]
      )
  where
    root = lookupModel schema (includeRootModel incl)
    (rel, child) = replaceChildRelation schema root incl
    wipeField = fieldBinder child (lookupField child (relForeignField rel))

emitWriteCreateType :: Model -> Model -> RelationSpec -> Text
emitWriteCreateType root child rel =
  T.unlines
    [ "data " <> writeCreateTypeName root <> " = " <> writeCreateTypeName root,
      "  { root :: " <> createTypeName root,
      "  , " <> childrenFieldName root rel <> " :: [" <> nestedCreateTypeName child <> "]",
      "  }",
      "  deriving (Show, Eq)",
      "",
      emitNestedCreateType child rel
    ]

emitWriteUpdateType :: Model -> Model -> RelationSpec -> Text
emitWriteUpdateType root child rel =
  T.unlines
    [ "data " <> writeUpdateTypeName root <> " = " <> writeUpdateTypeName root,
      "  { root :: " <> updateTypeName root,
      "  , " <> childrenFieldName root rel <> " :: Maybe [" <> nestedCreateTypeName child <> "]",
      "  }",
      "  deriving (Show, Eq)"
    ]

emitNestedCreateType :: Model -> RelationSpec -> Text
emitNestedCreateType child rel =
  T.unlines
    [ "data " <> nestedCreateTypeName child <> " = " <> nestedCreateTypeName child,
      "  { " <> T.intercalate ", " (nestedFieldLines child rel),
      "  }",
      "  deriving (Show, Eq)"
    ]

nestedFieldLines :: Model -> RelationSpec -> [Text]
nestedFieldLines child rel =
  [ fieldName f <> " :: " <> hsType (fieldType f)
    | f <- modelFields child,
      not (fieldIsPrimaryKey f),
      fieldName f /= relForeignField rel
  ]

emitNestedToChildCreate :: Model -> RelationSpec -> Text
emitNestedToChildCreate child rel =
  T.unlines $
    [ "to" <> createTypeName child <> " :: UUID -> " <> nestedCreateTypeName child <> " -> " <> createTypeName child,
      "to" <> createTypeName child <> " parentId nested =",
      "  " <> createTypeName child,
      "    { id = Nothing,"
    ]
      ++ [ "      " <> fieldName f <> " = nested." <> fieldName f <> ","
           | f <- modelFields child,
             not (fieldIsPrimaryKey f),
             fieldName f /= relForeignField rel
         ]
      ++ ["      " <> relForeignField rel <> " = parentId", "    }"]

emitWriteCreate :: Model -> ModelInclude -> Model -> RelationSpec -> Text
emitWriteCreate root incl child rel =
  let childrenField = childrenFieldName root rel
      toChild = "to" <> createTypeName child
      resultName = includeResultName root incl
      createBody =
        [ "  rootId <- maybe V4.nextRandom pure input.root.id",
          "  let rootInput :: " <> createTypeName root,
          "      rootInput = input.root { id = Just rootId }",
          "  rootResult <-",
          "    Insert.insertConn @" <> tableTypeName root <> " @" <> rowTypeName root <> " conn rootInput",
          "  case rootResult of",
          "    Left err -> pure (Left err)",
          "    Right _ -> do",
          "      forM_ input." <> childrenField <> " $ \\nested ->",
          "        Insert.executeInsertConn conn $",
          "          Insert.toInsertBuilder @" <> tableTypeName child <> " (" <> toChild <> " rootId nested)",
          "      Include.findUniqueOrErrorWithConn @" <> tableTypeName root <> " conn include rootId"
        ]
   in T.unlines $
        [ "createConn ::",
          "  Connection ->",
          "  " <> includeName incl <> " ->",
          "  " <> writeCreateTypeName root <> " ->",
          "  IO (Either ORMError " <> resultName <> ")",
          "createConn conn include input = do"
        ]
          ++ createBody
          ++ [ "",
               "create ::",
               "  Pool Connection ->",
               "  " <> includeName incl <> " ->",
               "  " <> writeCreateTypeName root <> " ->",
               "  IO (Either ORMError " <> resultName <> ")",
               "create pool include input =",
               "  transaction pool $ \\conn -> createConn conn include input"
             ]

emitWriteUpdate :: Model -> ModelInclude -> Model -> RelationSpec -> Text -> Text
emitWriteUpdate root incl child rel wipeField =
  let childrenField = childrenFieldName root rel
      toChild = "to" <> createTypeName child
      resultName = includeResultName root incl
      updateBody =
        [ "  now <- getCurrentTime",
          "  updateResult <-",
          "    Update.updateConn @" <> tableTypeName root <> " @" <> rowTypeName root <> " conn rootId (applyUpdatedAt now input.root)",
          "  case updateResult of",
          "    Left err -> pure (Left err)",
          "    Right _ -> do",
          "      case input." <> childrenField <> " of",
          "        Nothing -> pure ()",
          "        Just nestedItems -> do",
          "          _ <-",
          "            Delete.deleteWhereConn conn $",
          "              Delete.whereDelete (fieldColumn " <> wipeField <> " <> \" = ?\") [toField rootId] (Delete.emptyDelete @" <> tableTypeName child <> ")",
          "          forM_ nestedItems $ \\nested ->",
          "            Insert.executeInsertConn conn $",
          "              Insert.toInsertBuilder @" <> tableTypeName child <> " (" <> toChild <> " rootId nested)",
          "      Include.findUniqueOrErrorWithConn @" <> tableTypeName root <> " conn include rootId"
        ]
   in T.unlines $
        [ "updateConn ::",
          "  Connection ->",
          "  " <> includeName incl <> " ->",
          "  UUID ->",
          "  " <> writeUpdateTypeName root <> " ->",
          "  IO (Either ORMError " <> resultName <> ")",
          "updateConn conn include rootId input = do"
        ]
          ++ updateBody
          ++ [ "",
               "update ::",
               "  Pool Connection ->",
               "  " <> includeName incl <> " ->",
               "  UUID ->",
               "  " <> writeUpdateTypeName root <> " ->",
               "  IO (Either ORMError " <> resultName <> ")",
               "update pool include rootId input =",
               "  transaction pool $ \\conn -> updateConn conn include rootId input"
             ]

writeCreateTypeName :: Model -> Text
writeCreateTypeName model = modelName model <> "WriteCreate"

writeUpdateTypeName :: Model -> Text
writeUpdateTypeName model = modelName model <> "WriteUpdate"

nestedCreateTypeName :: Model -> Text
nestedCreateTypeName model = modelName model <> "NestedCreate"

childrenFieldName :: Model -> RelationSpec -> Text
childrenFieldName = includeFieldName

replaceChildRelation :: Schema -> Model -> ModelInclude -> (RelationSpec, Model)
replaceChildRelation schema root incl =
  case [ (rel, lookupModel schema (relToModel rel))
         | edge <- includeTree incl,
           let rel = lookupRelation root (includeRelation edge),
           relReplaceChildren rel
       ] of
    (found : _) -> found
    [] ->
      error $
        "emitWriteClientModule: include "
          <> T.unpack (includeName incl)
          <> " has no replaceChildren relation"

lookupField :: Model -> Text -> FieldSpec
lookupField model name =
  case find ((== name) . fieldName) (modelFields model) of
    Just f -> f
    Nothing ->
      error $
        "emit Client: unknown field "
          <> T.unpack name
          <> " on "
          <> T.unpack (modelName model)

hsType :: FieldType -> Text
hsType TyText = "Text"
hsType TyUuid = "UUID"
hsType TyInt = "Int"
hsType TyTimestamptz = "UTCTime"
hsType (TyEnum name) = name

applyUpdatedAtHelper :: Model -> Text
applyUpdatedAtHelper model =
  case find fieldUpdatedAt (modelFields model) of
    Just f ->
      T.unlines
        [ "applyUpdatedAt :: UTCTime -> " <> updateTypeName model <> " -> " <> updateTypeName model,
          "applyUpdatedAt now input = input { " <> fieldName f <> " = Just now }"
        ]
    Nothing ->
      T.unlines
        [ "applyUpdatedAt :: UTCTime -> " <> updateTypeName model <> " -> " <> updateTypeName model,
          "applyUpdatedAt _ input = input"
        ]

nestedEnumImports :: Schema -> Model -> [Text]
nestedEnumImports schema child =
  nubImports
    [ "import ORM.Schema." <> enumName e <> " (" <> enumName e <> ")"
      | f <- modelFields child,
        TyEnum wanted <- [fieldType f],
        e <- schemaEnums schema,
        enumName e == wanted,
        isNothing (enumImport e)
    ]
  where
    nubImports = foldr go []
      where
        go imp acc | imp `elem` acc = acc
        go imp acc = imp : acc

emitSimpleExports :: Text
emitSimpleExports =
  T.unlines
    [ "  ( create,",
      "    createConn,",
      "    update,",
      "    updateConn,",
      "    findAll,",
      "    findAllConn,",
      "    findUnique,",
      "    findUniqueConn,",
      "    findUniqueOrError,",
      "    findUniqueOrErrorConn,",
      "    deleteById,",
      "    deleteByIdConn",
      "  )"
    ]

exportLinesFromItems :: [Text] -> [Text]
exportLinesFromItems items =
  case items of
    [] -> ["  ()"]
    (first : rest) ->
      ("  ( " <> first) : map ("    " <>) rest ++ ["  )"]

includeReadExportItems :: Schema -> ModelInclude -> [Text]
includeReadExportItems schema incl =
  includeReadFunctionExportItems ++ includeReadPresetExportItems schema incl

includeReadFunctionExportItems :: [Text]
includeReadFunctionExportItems =
  [ "findAllWith,",
    "findManyWith,",
    "findUniqueWith,",
    "findUniqueOrErrorWith,",
    "findAllWithConn,",
    "findManyWithConn,",
    "findUniqueWithConn,",
    "findUniqueOrErrorWithConn,"
  ]

includeReadPresetExportItems :: Schema -> ModelInclude -> [Text]
includeReadPresetExportItems schema incl =
  [ fullPresetName schema incl <> ",",
    "noInclude"
  ]

includeReadImportLines :: Text -> Schema -> ModelInclude -> [Text]
includeReadImportLines moduleName schema incl =
  [ "import Data.Pool (Pool)",
    "import Data.UUID (UUID)",
    "import Database.PostgreSQL.Simple (Connection)",
    "import ORM.Errors (ORMError)",
    "import qualified ORM.Include as Include",
    "import ORM.Query (QueryBuilder)",
    "import "
      <> schemaModule moduleName root
      <> " ("
      <> tableTypeName root
      <> ")",
    includeModuleImportLine moduleName schema incl
  ]
  where
    root = lookupModel schema (includeRootModel incl)

includeModuleImportLine :: Text -> Schema -> ModelInclude -> Text
includeModuleImportLine moduleName schema incl =
  let root = lookupModel schema (includeRootModel incl)
      typeExports = nestedIncludeTypeExports schema incl
   in "import "
        <> includeModule moduleName incl
        <> " ( "
        <> includeName incl
        <> " (..), "
        <> T.intercalate ", " typeExports
        <> ", "
        <> resultTypeName schema root (includeTree incl)
        <> " (..))"

nestedIncludeTypeExports :: Schema -> ModelInclude -> [Text]
nestedIncludeTypeExports schema incl =
  let root = lookupModel schema (includeRootModel incl)
   in [ modelName nested <> "Include (..)"
        | edge <- includeTree incl,
          let rel = lookupRelation root (includeRelation edge),
          let nested = lookupModel schema (relToModel rel),
          not (null (includeChildren edge))
      ]

emitIncludeReadDefinitions :: Schema -> ModelInclude -> [Text]
emitIncludeReadDefinitions schema incl =
  let root = lookupModel schema (includeRootModel incl)
   in [ emitFullIncludePreset schema incl,
        emitNoIncludePreset schema incl,
        emitIncludeFindAll root incl,
        emitIncludeFindAllWithConn root incl,
        emitIncludeFindMany root incl,
        emitIncludeFindManyWithConn root incl,
        emitIncludeFindUnique root incl,
        emitIncludeFindUniqueWithConn root incl,
        emitIncludeFindUniqueOrError root incl,
        emitIncludeFindUniqueOrErrorWithConn root incl
      ]

intercalateSections :: [Text] -> Text
intercalateSections sections =
  T.intercalate "\n\n" (map T.strip sections)

emitCreateFn :: Model -> Text
emitCreateFn model =
  T.unlines
    [ "create :: Pool Connection -> " <> createTypeName model <> " -> IO (Either ORMError " <> rowTypeName model <> ")",
      "create = Insert.insert @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitCreateConnFn :: Model -> Text
emitCreateConnFn model =
  T.unlines
    [ "createConn :: Connection -> " <> createTypeName model <> " -> IO (Either ORMError " <> rowTypeName model <> ")",
      "createConn = Insert.insertConn @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitUpdateFn :: Model -> Text
emitUpdateFn model =
  T.unlines
    [ "update :: Pool Connection -> UUID -> " <> updateTypeName model <> " -> IO (Either ORMError " <> rowTypeName model <> ")",
      "update = Update.update @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitUpdateConnFn :: Model -> Text
emitUpdateConnFn model =
  T.unlines
    [ "updateConn :: Connection -> UUID -> " <> updateTypeName model <> " -> IO (Either ORMError " <> rowTypeName model <> ")",
      "updateConn = Update.updateConn @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindAllFn :: Model -> Text
emitFindAllFn model =
  T.unlines
    [ "findAll :: Pool Connection -> IO [" <> rowTypeName model <> "]",
      "findAll = Ops.findAll @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindAllConnFn :: Model -> Text
emitFindAllConnFn model =
  T.unlines
    [ "findAllConn :: Connection -> IO [" <> rowTypeName model <> "]",
      "findAllConn = Ops.findAllConn @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindUniqueFn :: Model -> Text
emitFindUniqueFn model =
  T.unlines
    [ "findUnique :: Pool Connection -> UUID -> IO (Maybe " <> rowTypeName model <> ")",
      "findUnique = Ops.findUnique @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindUniqueConnFn :: Model -> Text
emitFindUniqueConnFn model =
  T.unlines
    [ "findUniqueConn :: Connection -> UUID -> IO (Maybe " <> rowTypeName model <> ")",
      "findUniqueConn = Ops.findUniqueConn @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindUniqueOrErrorFn :: Model -> Text
emitFindUniqueOrErrorFn model =
  T.unlines
    [ "findUniqueOrError :: Pool Connection -> UUID -> IO (Either ORMError " <> rowTypeName model <> ")",
      "findUniqueOrError = Ops.findUniqueOrError @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindUniqueOrErrorConnFn :: Model -> Text
emitFindUniqueOrErrorConnFn model =
  T.unlines
    [ "findUniqueOrErrorConn :: Connection -> UUID -> IO (Either ORMError " <> rowTypeName model <> ")",
      "findUniqueOrErrorConn = Ops.findUniqueOrErrorConn @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitDeleteFn :: Model -> Text
emitDeleteFn model =
  T.unlines
    [ "deleteById :: Pool Connection -> UUID -> IO Int",
      "deleteById = Ops.deleteById @" <> tableTypeName model
    ]

emitDeleteByIdConnFn :: Model -> Text
emitDeleteByIdConnFn model =
  T.unlines
    [ "deleteByIdConn :: Connection -> UUID -> IO Int",
      "deleteByIdConn = Ops.deleteByIdConn @" <> tableTypeName model
    ]

emitFullIncludePreset :: Schema -> ModelInclude -> Text
emitFullIncludePreset schema incl =
  T.unlines
    [ fullPresetName schema incl <> " :: " <> includeName incl,
      fullPresetName schema incl <> " =",
      "  " <> fullIncludeValue schema incl
    ]

emitNoIncludePreset :: Schema -> ModelInclude -> Text
emitNoIncludePreset schema incl =
  T.unlines
    [ "noInclude :: " <> includeName incl,
      "noInclude = " <> noIncludeValue schema incl
    ]

emitIncludeFindAll :: Model -> ModelInclude -> Text
emitIncludeFindAll model incl =
  T.unlines
    [ "findAllWith :: Pool Connection -> " <> includeName incl <> " -> IO [" <> includeResultName model incl <> "]",
      "findAllWith = Include.findAllWith @" <> tableTypeName model
    ]

emitIncludeFindAllWithConn :: Model -> ModelInclude -> Text
emitIncludeFindAllWithConn model incl =
  T.unlines
    [ "findAllWithConn :: Connection -> " <> includeName incl <> " -> IO [" <> includeResultName model incl <> "]",
      "findAllWithConn = Include.findAllWithConn @" <> tableTypeName model
    ]

emitIncludeFindMany :: Model -> ModelInclude -> Text
emitIncludeFindMany model incl =
  T.unlines
    [ "findManyWith ::",
      "  Pool Connection ->",
      "  " <> includeName incl <> " ->",
      "  (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ") ->",
      "  IO [" <> resultName <> "]",
      "findManyWith = Include.findManyWith @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindManyWithConn :: Model -> ModelInclude -> Text
emitIncludeFindManyWithConn model incl =
  T.unlines
    [ "findManyWithConn ::",
      "  Connection ->",
      "  " <> includeName incl <> " ->",
      "  (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ") ->",
      "  IO [" <> resultName <> "]",
      "findManyWithConn = Include.findManyWithConn @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindUnique :: Model -> ModelInclude -> Text
emitIncludeFindUnique model incl =
  T.unlines
    [ "findUniqueWith :: Pool Connection -> " <> includeName incl <> " -> UUID -> IO (Maybe " <> resultName <> ")",
      "findUniqueWith = Include.findUniqueWith @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindUniqueWithConn :: Model -> ModelInclude -> Text
emitIncludeFindUniqueWithConn model incl =
  T.unlines
    [ "findUniqueWithConn :: Connection -> " <> includeName incl <> " -> UUID -> IO (Maybe " <> resultName <> ")",
      "findUniqueWithConn = Include.findUniqueWithConn @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindUniqueOrError :: Model -> ModelInclude -> Text
emitIncludeFindUniqueOrError model incl =
  T.unlines
    [ "findUniqueOrErrorWith :: Pool Connection -> " <> includeName incl <> " -> UUID -> IO (Either ORMError " <> resultName <> ")",
      "findUniqueOrErrorWith = Include.findUniqueOrErrorWith @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindUniqueOrErrorWithConn :: Model -> ModelInclude -> Text
emitIncludeFindUniqueOrErrorWithConn model incl =
  T.unlines
    [ "findUniqueOrErrorWithConn :: Connection -> " <> includeName incl <> " -> UUID -> IO (Either ORMError " <> resultName <> ")",
      "findUniqueOrErrorWithConn = Include.findUniqueOrErrorWithConn @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

includeResultName :: Model -> ModelInclude -> Text
includeResultName model incl =
  resultTypeName stubSchema model (includeTree incl)
  where
    stubSchema = Schema {schemaEnums = [], schemaModels = [model], schemaIncludes = [incl]}

fullIncludeValue :: Schema -> ModelInclude -> Text
fullIncludeValue schema incl =
  includeName incl
    <> " {"
    <> T.intercalate ", " (map (fullIncludeEdge schema root) (includeTree incl))
    <> "}"
  where
    root = lookupModel schema (includeRootModel incl)

fullIncludeEdge :: Schema -> Model -> IncludeTree -> Text
fullIncludeEdge schema parent edge =
  includeFieldName parent rel
    <> " = Just ("
    <> nestedIncludeValue schema parent edge
    <> ")"
  where
    rel = lookupRelation parent (includeRelation edge)

nestedIncludeValue :: Schema -> Model -> IncludeTree -> Text
nestedIncludeValue schema parent edge =
  nestedType
    <> " {"
    <> T.intercalate ", " (map (nestedBoolField schema child) (includeChildren edge))
    <> "}"
  where
    rel = lookupRelation parent (includeRelation edge)
    child = lookupModel schema (relToModel rel)
    nestedType = modelName child <> "Include"

nestedBoolField :: Schema -> Model -> IncludeTree -> Text
nestedBoolField _ child edge =
  includeFieldName child rel <> " = True"
  where
    rel = lookupRelation child (includeRelation edge)

noIncludeValue :: Schema -> ModelInclude -> Text
noIncludeValue schema incl =
  includeName incl
    <> " {"
    <> T.intercalate ", " (map (noIncludeEdge schema root) (includeTree incl))
    <> "}"
  where
    root = lookupModel schema (includeRootModel incl)

noIncludeEdge :: Schema -> Model -> IncludeTree -> Text
noIncludeEdge _ parent edge =
  includeFieldName parent rel <> " = Nothing"
  where
    rel = lookupRelation parent (includeRelation edge)

fullPresetName :: Schema -> ModelInclude -> Text
fullPresetName schema incl =
  "with"
    <> T.concat
      [ upperFirst (includeFieldName root rel)
        | let root = lookupModel schema (includeRootModel incl),
          edge <- includeTree incl,
          let rel = lookupRelation root (includeRelation edge)
      ]

includeFieldName :: Model -> RelationSpec -> Text
includeFieldName parent rel =
  case T.stripPrefix (lowerFirst (modelName parent)) (relName rel) of
    Just rest | not (T.null rest) -> lowerFirst rest
    _ -> lowerFirst (relToModel rel)

resultTypeName :: Schema -> Model -> [IncludeTree] -> Text
resultTypeName _schema model edges =
  modelName model
    <> "With"
    <> T.concat (map (upperFirst . fieldOf) edges)
  where
    fieldOf edge =
      includeFieldName model (lookupRelation model (includeRelation edge))

schemaModule :: Text -> Model -> Text
schemaModule clientModule model =
  clientSchemaPrefix clientModule <> modelName model

includeModule :: Text -> ModelInclude -> Text
includeModule clientModule incl =
  clientSchemaPrefix clientModule <> includeName incl

clientSchemaPrefix :: Text -> Text
clientSchemaPrefix clientModule =
  case T.stripPrefix "ORM.Client." clientModule of
    Just _ -> "ORM.Schema."
    _ -> "Schema."

tableTypeName :: Model -> Text
tableTypeName model = modelName model <> "Table"

rowTypeName :: Model -> Text
rowTypeName model = modelName model <> "Row"

createTypeName :: Model -> Text
createTypeName model = modelName model <> "Create"

updateTypeName :: Model -> Text
updateTypeName model = modelName model <> "Update"

fieldBinder :: Model -> FieldSpec -> Text
fieldBinder model f =
  lowerFirst (modelName model) <> upperFirst (fieldName f)

lookupModel :: Schema -> Text -> Model
lookupModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just m -> m
    Nothing -> error $ "emit Client: unknown model " <> T.unpack name

lookupRelation :: Model -> Text -> RelationSpec
lookupRelation model name =
  case find ((== name) . relName) (modelRelations model) of
    Just r -> r
    Nothing ->
      error $
        "emit Client: unknown relation "
          <> T.unpack name
          <> " on "
          <> T.unpack (modelName model)

lowerFirst :: Text -> Text
lowerFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toLower c) rest

upperFirst :: Text -> Text
upperFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toUpper c) rest
