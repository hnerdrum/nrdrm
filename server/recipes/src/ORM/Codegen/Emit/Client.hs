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
    [ "{-# LANGUAGE RecordWildCards #-}",
      "{-# LANGUAGE TypeApplications #-}",
      "",
      "module " <> moduleName,
      emitSimpleExports model,
      "where",
      "",
      "import Data.UUID (UUID)",
      "import ORM.Db (Db)",
      "import ORM.Errors (ORMError)",
      "import qualified ORM.Delete as Delete",
      "import qualified ORM.Insert as Insert",
      "import qualified ORM.Operations as Ops",
      "import ORM.Query (QueryBuilder, applyQueryModifiers)",
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
      emitUpdateFn model,
      "",
      emitQueryType model,
      "",
      emitEmptyQueryFn model,
      "",
      emitFindManyFn model,
      "",
      emitFindUniqueFn model,
      "",
      emitFindUniqueOrFailFn model,
      "",
      emitDeleteFn model,
      "",
      emitDeleteManyFn model
    ]

emitIncludeReadClientModule :: Text -> Schema -> ModelInclude -> Text
emitIncludeReadClientModule moduleName schema incl =
  T.unlines
    ( [ "{-# LANGUAGE FlexibleContexts #-}",
        "{-# LANGUAGE MultiParamTypeClasses #-}",
        "{-# LANGUAGE RecordWildCards #-}",
        "{-# LANGUAGE TypeApplications #-}",
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
        "{-# LANGUAGE FlexibleContexts #-}",
        "{-# LANGUAGE MultiParamTypeClasses #-}",
        "{-# LANGUAGE OverloadedRecordDot #-}",
        "{-# LANGUAGE RecordWildCards #-}",
        "{-# LANGUAGE TypeApplications #-}",
        "",
        "module " <> moduleName
      ]
        ++ exportLinesFromItems
          ( includeReadFunctionExportItems
              ++ [ "create,",
                   "update,",
                   "delete,",
                   "deleteMany,",
                   writeCreateTypeName root <> " (..),",
                   writeUpdateTypeName root <> " (..),",
                   nestedCreateTypeName child <> " (..),"
                 ]
              ++ includeReadPresetExportItems schema incl
              ++ [queryTypeName root <> " (..),"]
          )
        ++ ["where", ""]
        ++ [ "import Control.Monad (forM_)",
             "import Data.UUID (UUID)",
             "import qualified Data.UUID.V4 as V4",
             "import Database.PostgreSQL.Simple.ToField (toField)",
             "import ORM.Core (fieldColumn)",
             "import ORM.Db (Db, liftIO)",
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
             "import qualified ORM.Operations as Ops",
             "import ORM.Query (QueryBuilder, applyQueryModifiers)",
             "import qualified ORM.Update as Update"
           ]
        ++ nestedEnumImports schema child
    )
    <> "\n"
    <> intercalateSections
      ( [ emitWriteCreateType root child rel,
          emitWriteUpdateType root child rel,
          emitNestedToChildCreate child rel
        ]
          ++ emitIncludeReadDefinitions schema incl
          ++ [ emitWriteCreate root incl child rel,
               emitWriteUpdate root incl child rel wipeField,
               emitDeleteFn root,
               emitDeleteManyFn root
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
        [ "  rootId <- liftIO $ maybe V4.nextRandom pure input.root.id",
          "  let rootInput =",
          "        " <> createRootInputExpr root,
          "  rootResult <-",
          "    Insert.insert @" <> tableTypeName root <> " @" <> rowTypeName root <> " rootInput",
          "  case rootResult of",
          "    Left err -> pure (Left err)",
          "    Right _ -> do",
          "      forM_ input." <> childrenField <> " $ \\nested ->",
          "        Insert.executeInsert $",
          "          Insert.toInsertBuilder @" <> tableTypeName child <> " (" <> toChild <> " rootId nested)",
          "      Include.findUniqueOrFail @" <> tableTypeName root <> " include rootId"
        ]
   in T.unlines $
        [ "create ::",
          "  " <> includeName incl <> " ->",
          "  " <> writeCreateTypeName root <> " ->",
          "  Db (Either ORMError " <> resultName <> ")",
          "create include input = do"
        ]
          ++ createBody

emitWriteUpdate :: Model -> ModelInclude -> Model -> RelationSpec -> Text -> Text
emitWriteUpdate root incl child rel wipeField =
  let childrenField = childrenFieldName root rel
      toChild = "to" <> createTypeName child
      resultName = includeResultName root incl
      updateBody =
        [ "  updateResult <-",
          "    Update.update @" <> tableTypeName root <> " @" <> rowTypeName root <> " rootId input.root",
          "  case updateResult of",
          "    Left err -> pure (Left err)",
          "    Right _ -> do",
          "      case input." <> childrenField <> " of",
          "        Nothing -> pure ()",
          "        Just nestedItems -> do",
          "          _ <-",
          "            Delete.deleteWhere $",
          "              Delete.whereDelete (fieldColumn " <> wipeField <> " <> \" = ?\") [toField rootId] (Delete.emptyDelete @" <> tableTypeName child <> ")",
          "          forM_ nestedItems $ \\nested ->",
          "            Insert.executeInsert $",
          "              Insert.toInsertBuilder @" <> tableTypeName child <> " (" <> toChild <> " rootId nested)",
          "      Include.findUniqueOrFail @" <> tableTypeName root <> " include rootId"
        ]
   in T.unlines $
        [ "update ::",
          "  " <> includeName incl <> " ->",
          "  UUID ->",
          "  " <> writeUpdateTypeName root <> " ->",
          "  Db (Either ORMError " <> resultName <> ")",
          "update include rootId input = do"
        ]
          ++ updateBody

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

createRootInputExpr :: Model -> Text
createRootInputExpr model =
  let cn = createTypeName model
      fieldLines =
        map createRootFieldLine (modelFields model)
   in cn
        <> " { "
        <> T.intercalate ", " fieldLines
        <> " }"

createRootFieldLine :: FieldSpec -> Text
createRootFieldLine f
  | fieldIsPrimaryKey f = fieldName f <> " = Just rootId"
  | otherwise = fieldName f <> " = input.root." <> fieldName f

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

emitSimpleExports :: Model -> Text
emitSimpleExports model =
  T.unlines
    [ "  ( create,",
      "    update,",
      "    findMany,",
      "    findUnique,",
      "    findUniqueOrFail,",
      "    delete,",
      "    deleteMany,",
      "    " <> queryTypeName model <> " (..),",
      "    emptyQuery",
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
  includeReadFunctionExportItems
    ++ includeReadPresetExportItems schema incl
    ++ [queryTypeName (lookupModel schema (includeRootModel incl)) <> " (..),"]

includeReadFunctionExportItems :: [Text]
includeReadFunctionExportItems =
  [ "findMany,",
    "findUnique,",
    "findUniqueOrFail,"
  ]

includeReadPresetExportItems :: Schema -> ModelInclude -> [Text]
includeReadPresetExportItems schema incl =
  [ fullPresetName schema incl <> ",",
    "noInclude,"
  ]

includeReadImportLines :: Text -> Schema -> ModelInclude -> [Text]
includeReadImportLines moduleName schema incl =
  [ "import Data.UUID (UUID)",
    "import ORM.Db (Db)",
    "import ORM.Errors (ORMError)",
    "import qualified ORM.Include as Include",
    "import ORM.Query (QueryBuilder, applyQueryModifiers)",
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
        emitIncludeQueryType root incl,
        emitIncludeFindManyClass root incl,
        emitIncludeFindManyInstances root incl,
        emitIncludeFindUnique root incl,
        emitIncludeFindUniqueOrFail root incl
      ]

intercalateSections :: [Text] -> Text
intercalateSections sections =
  T.intercalate "\n\n" (map T.strip sections)

emitCreateFn :: Model -> Text
emitCreateFn model =
  T.unlines
    [ "create :: " <> createTypeName model <> " -> Db (Either ORMError " <> rowTypeName model <> ")",
      "create = Insert.insert @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitUpdateFn :: Model -> Text
emitUpdateFn model =
  T.unlines
    [ "update :: UUID -> " <> updateTypeName model <> " -> Db (Either ORMError " <> rowTypeName model <> ")",
      "update = Update.update @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindManyFn :: Model -> Text
emitFindManyFn model =
  T.unlines
    [ "findMany :: " <> queryTypeName model <> " -> Db [" <> rowTypeName model <> "]",
      "findMany q =",
      "  Ops.findMany @" <> tableTypeName model <> " @" <> rowTypeName model <> " (applyQuery q)",
      "",
      "applyQuery :: " <> queryTypeName model <> " -> QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model,
      "applyQuery " <> queryTypeName model <> " {..} =",
      "  applyQueryModifiers where_ orderBy_ limit_ offset_"
    ]

emitEmptyQueryFn :: Model -> Text
emitEmptyQueryFn model =
  T.unlines
    [ "emptyQuery :: " <> queryTypeName model,
      "emptyQuery =",
      "  " <> queryTypeName model <> " {where_ = Nothing, orderBy_ = Nothing, limit_ = Nothing, offset_ = Nothing}"
    ]

emitQueryType :: Model -> Text
emitQueryType model =
  T.unlines
    [ "data " <> queryTypeName model <> " = " <> queryTypeName model,
      "  { where_ :: Maybe (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ")",
      "  , orderBy_ :: Maybe (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ")",
      "  , limit_ :: Maybe Int",
      "  , offset_ :: Maybe Int",
      "  }"
    ]

emitFindUniqueFn :: Model -> Text
emitFindUniqueFn model =
  T.unlines
    [ "findUnique :: UUID -> Db (Maybe " <> rowTypeName model <> ")",
      "findUnique = Ops.findUnique @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindUniqueOrFailFn :: Model -> Text
emitFindUniqueOrFailFn model =
  T.unlines
    [ "findUniqueOrFail :: UUID -> Db (Either ORMError " <> rowTypeName model <> ")",
      "findUniqueOrFail = Ops.findUniqueOrError @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitDeleteFn :: Model -> Text
emitDeleteFn model =
  T.unlines
    [ "delete :: UUID -> Db Int",
      "delete = Ops.deleteById @" <> tableTypeName model
    ]

emitDeleteManyFn :: Model -> Text
emitDeleteManyFn model =
  T.unlines
    [ "deleteMany :: (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ") -> Db Int",
      "deleteMany = Delete.deleteMany @" <> tableTypeName model
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

emitIncludeQueryType :: Model -> ModelInclude -> Text
emitIncludeQueryType model incl =
  T.unlines
    [ "data " <> queryTypeName model <> " = " <> queryTypeName model,
      "  { include :: " <> includeName incl,
      "  , where_ :: Maybe (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ")",
      "  , orderBy_ :: Maybe (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ")",
      "  , limit_ :: Maybe Int",
      "  , offset_ :: Maybe Int",
      "  }"
    ]

emitIncludeFindManyClass :: Model -> ModelInclude -> Text
emitIncludeFindManyClass model incl =
  T.unlines
    [ "class FindMany" <> modelName model <> " a where",
      "  findMany :: a -> Db [" <> includeResultName model incl <> "]"
    ]

emitIncludeFindManyInstances :: Model -> ModelInclude -> Text
emitIncludeFindManyInstances model incl =
  T.unlines
    [ "instance FindMany" <> modelName model <> " " <> includeName incl <> " where",
      "  findMany include =",
      "    findMany",
      "      " <> queryTypeName model,
      "        { include = include,",
      "          where_ = Nothing,",
      "          orderBy_ = Nothing,",
      "          limit_ = Nothing,",
      "          offset_ = Nothing",
      "        }",
      "",
      "instance FindMany" <> modelName model <> " " <> queryTypeName model <> " where",
      "  findMany " <> queryTypeName model <> " {..} =",
      "    Include.findMany @" <> tableTypeName model <> " include (applyQueryModifiers where_ orderBy_ limit_ offset_)"
    ]

emitIncludeFindUnique :: Model -> ModelInclude -> Text
emitIncludeFindUnique model incl =
  T.unlines
    [ "findUnique :: " <> includeName incl <> " -> UUID -> Db (Maybe " <> resultName <> ")",
      "findUnique = Include.findUnique @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindUniqueOrFail :: Model -> ModelInclude -> Text
emitIncludeFindUniqueOrFail model incl =
  T.unlines
    [ "findUniqueOrFail :: " <> includeName incl <> " -> UUID -> Db (Either ORMError " <> resultName <> ")",
      "findUniqueOrFail = Include.findUniqueOrFail @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

queryTypeName :: Model -> Text
queryTypeName model = modelName model <> "Query"

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
