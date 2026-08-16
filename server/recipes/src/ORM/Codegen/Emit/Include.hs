{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.Include
  ( emitIncludeADTs,
    emitResultADTs,
    emitIncludesJoin,
    emitBuildJoinChain,
    emitExecuteInclude,
    emitNestInclude,
    emitIncludeModule,
  )
where

import Data.Char (toLower, toUpper)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.Emit.FlatRow
  ( emitColumnList,
    emitFlatJoinRow,
    emitJoinBuilder,
  )
import ORM.Codegen.Emit.Nest
  ( emitNestHelpersForPath,
    includePatternForPath,
    nestRowsFnName,
    nestedIncludePatternForPath,
  )
import ORM.Codegen.Emit.Schema (enumImportLine)
import ORM.Codegen.IR
import ORM.Codegen.IncludePath
  ( JoinPath (..),
    PathStep (..),
    includeLongestJoinPath,
    includePresetJoinPaths,
    joinBuilderName,
    joinPathModels,
    joinPathTake,
    joinRowName,
  )

data IncludeTypeDecl = IncludeTypeDecl
  { itdName :: Text,
    itdParent :: Model,
    itdEdges :: [IncludeTree]
  }

emitIncludeADTs :: Schema -> ModelInclude -> Text
emitIncludeADTs schema incl =
  T.intercalate "\n" $
    map (emitTypeDecl schema) (collectIncludeTypes schema incl)

emitResultADTs :: Schema -> ModelInclude -> Text
emitResultADTs schema incl =
  T.intercalate "\n" $
    map (emitResultTypeDecl schema) (collectResultTypes schema incl)

emitNestInclude :: Schema -> ModelInclude -> Text
emitNestInclude schema incl =
  T.unlines
    [ "instance NestInclude " <> includeName incl <> " " <> resultName <> " where",
      "  type RootRow " <> includeName incl <> " = " <> rootRow,
      "  nestRows _ = " <> nestFn,
      "  wrapRoot _ " <> rootVar <> " = " <> resultName <> " {" <> rootVar <> ", " <> emptyFields <> "}"
    ]
  where
    root = lookupModel schema (includeRootModel incl)
    resultName = resultTypeName schema root (includeTree incl)
    rootRow = modelName root <> "Row"
    rootVar = lowerFirst (modelName root)
    nestFn = nestRowsName root
    emptyFields =
      T.intercalate ", " $
        map (emptyIncludeField schema root) (includeTree incl)

emptyIncludeField :: Schema -> Model -> IncludeTree -> Text
emptyIncludeField _schema parent edge =
  name <> " = " <> emptyVal
  where
    rel = lookupRelation parent (includeRelation edge)
    name = includeFieldName parent rel
    emptyVal = case relKind rel of
      RelHasMany -> "[]"
      RelBelongsTo -> "Nothing"

nestRowsName :: Model -> Text
nestRowsName root = "nest" <> modelName root <> "Rows"

emitIncludesJoin :: Schema -> ModelInclude -> Text
emitIncludesJoin schema incl =
  T.unlines
    [ "instance IncludesJoin " <> includeName incl <> " where",
      "  includesJoin " <> includeName incl <> " {" <> fld <> "} = " <> expr
    ]
  where
    root = lookupModel schema (includeRootModel incl)
    edge = case includeTree incl of
      (e : _) -> e
      [] -> error "emitIncludesJoin: empty include tree"
    rel = lookupRelation root (includeRelation edge)
    fld = includeFieldName root rel
    expr =
      if null (includeChildren edge)
        then fld
        else "isJust " <> fld

emitBuildJoinChain :: Schema -> ModelInclude -> Text
emitBuildJoinChain schema incl =
  T.unlines $
    [ "instance BuildJoinChain " <> rootTable <> " " <> inclName <> " where",
      "  type JoinFlatRow " <> inclName <> " = " <> shallowRow
    ]
      ++ buildJoinChainArms schema incl
  where
    path = includeLongestJoinPath schema incl
    root = head (joinPathModels path)
    rootTable = modelName root <> "Table"
    inclName = includeName incl
    shallowRow = joinRowName (joinPathTake 1 path)

buildJoinChainArms :: Schema -> ModelInclude -> [Text]
buildJoinChainArms schema incl =
  presetArms ++ noJoinArm
  where
    root = head (joinPathModels (includeLongestJoinPath schema incl))
    inclName = includeName incl
    paths = includePresetJoinPaths schema incl
    shallowBuilder = joinBuilderName (joinPathTake 1 (includeLongestJoinPath schema incl))
    presetArms =
      concatMap
        ( \path ->
            [ "  buildJoinChain " <> includePatternForPath schema incl path <> " =",
              "    " <> joinBuilderName path
            ]
        )
        paths
    noJoinArm =
      case includeTree incl of
        (edge : _)
          | not (null (includeChildren edge)) ->
              let rel = lookupRelation root (includeRelation edge)
               in [ "  buildJoinChain " <> inclName <> " {" <> includeFieldName root rel <> " = Nothing} =",
                    "    " <> shallowBuilder
                  ]
        _ -> ["  buildJoinChain _ = " <> shallowBuilder]

emitExecuteInclude :: Schema -> ModelInclude -> Text
emitExecuteInclude schema incl =
  T.unlines $
    [ "instance {-# OVERLAPPING #-} ExecuteInclude " <> rootTable <> " " <> inclName <> " " <> resultName <> " where",
      "  executeInclude conn include modifier =",
      "    case include." <> rootField <> " of",
      "      Nothing -> do",
      "        roots <- findManyConn @" <> rootTable <> " @" <> rootRow <> " conn modifier",
      "        pure $ map (wrapRoot include) roots"
    ]
      ++ concatMap (executeIncludeArm schema incl) (includePresetJoinPaths schema incl)
  where
    path = includeLongestJoinPath schema incl
    root = head (joinPathModels path)
    rootRel = psRel (head (jpSteps path))
    rootTable = modelName root <> "Table"
    inclName = includeName incl
    resultName = resultTypeName schema root (includeTree incl)
    rootRow = modelName root <> "Row"
    rootField = includeFieldName root rootRel

executeIncludeArm :: Schema -> ModelInclude -> JoinPath -> [Text]
executeIncludeArm schema incl path =
  [ "      " <> nestedIncludePatternForPath schema incl path <> " -> do",
    "        let chain = applyRootFilter " <> joinBuilderName path <> " modifier",
    "        flatRows <- JoinChain.runJoinChainConn @" <> joinRowName path <> " conn chain",
    "        pure $ " <> nestRowsFnName path <> " flatRows"
  ]

emitIncludeModule :: Text -> Schema -> ModelInclude -> Text
emitIncludeModule moduleName schema incl =
  T.unlines $
    concat
      [ includePragmas,
        [ "module " <> moduleName,
          emitIncludeExports schema incl,
          "where",
          "",
          emitIncludeImports moduleName schema incl,
          ""
        ],
        [ emitIncludeADTs schema incl,
          emitResultADTs schema incl,
          emitIncludesJoin schema incl
        ],
        pathPieces schema incl,
        [ emitBuildJoinChain schema incl,
          emitNestInclude schema incl
        ],
        nestPieces schema incl,
        [emitExecuteInclude schema incl | hasIncludeJoins incl]
      ]
  where
    pathPieces schema' incl' =
      concatMap
        ( \path ->
            [ emitFlatJoinRow schema' path,
              emitColumnList schema' path,
              emitJoinBuilder schema' path
            ]
        )
        (includePresetJoinPaths schema' incl')

    nestPieces schema' incl' =
      map (emitNestHelpersForPath schema' incl') (includePresetJoinPaths schema' incl')

hasIncludeJoins :: ModelInclude -> Bool
hasIncludeJoins incl = not (null (includeTree incl))

includePragmas :: [Text]
includePragmas =
  [ "{-# LANGUAGE AllowAmbiguousTypes #-}",
    "{-# LANGUAGE DuplicateRecordFields #-}",
    "{-# LANGUAGE FlexibleContexts #-}",
    "{-# LANGUAGE MultiParamTypeClasses #-}",
    "{-# LANGUAGE NoFieldSelectors #-}",
    "{-# LANGUAGE OverloadedRecordDot #-}",
    "{-# LANGUAGE TypeApplications #-}",
    "{-# LANGUAGE TypeFamilies #-}",
    "{-# LANGUAGE UndecidableInstances #-}",
    ""
  ]

emitIncludeExports :: Schema -> ModelInclude -> Text
emitIncludeExports schema incl =
  "  ( "
    <> T.intercalate ",\n    " items
    <> "\n  )"
  where
    nestedExport =
      [ itdName d <> " (..)"
        | d <- collectIncludeTypes schema incl,
          itdName d /= includeName incl
      ]
    resultExports =
      [ itdName d <> " (..)"
        | d <- collectResultTypes schema incl
      ]
    flatExports =
      [ joinRowName path <> " (..)"
        | path <- includePresetJoinPaths schema incl
      ]
    items =
      [includeName incl <> " (..)"]
        ++ nestedExport
        ++ resultExports
        ++ flatExports

emitIncludeImports :: Text -> Schema -> ModelInclude -> Text
emitIncludeImports moduleName schema incl =
  T.intercalate "\n" $
    filter
      (not . T.null)
      [ "import Data.Maybe (fromMaybe, isJust, mapMaybe)",
        if needsText then "import Data.Text (Text)" else "",
        if needsUuid then "import Data.UUID (UUID)" else "",
        if needsTime then "import Data.Time (UTCTime)" else "",
        "import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)",
        "import ORM.Group (groupByKey)",
        "import ORM.Include",
        "  ( BuildJoinChain (..),",
        "    ExecuteInclude (..),",
        "    IncludesJoin (..),",
        "    NestInclude (..),",
        "    applyRootFilter,",
        "  )",
        "import qualified ORM.JoinChain as JoinChain",
        "import ORM.Operations (findManyConn)",
        rootImport
      ]
      ++ tailImports
      ++ map (qualifiedImport moduleName) models
      ++ enumImports (schemaModulePrefix moduleName) schema incl
  where
    path = includeLongestJoinPath schema incl
    models = joinPathModels path
    steps = jpSteps path
    sjRoot = head models
    sjRel = psRel (head steps)
    allFields = includeFields schema incl
    needsText = any ((== TyText) . fieldType) allFields
    needsUuid = any ((== TyUuid) . fieldType) allFields
    needsTime = any ((== TyTimestamptz) . fieldType) allFields
    rootMod = schemaModulePrefix moduleName <> modelName sjRoot
    rootImport =
      "import "
        <> rootMod
        <> " ("
        <> T.intercalate
          ", "
          [ modelName sjRoot <> "Table",
            modelName sjRoot <> "Row (..)",
            relName sjRel
          ]
        <> ")"
    tailImports =
      map (modelImport moduleName path) (drop 1 models)

modelImport :: Text -> JoinPath -> Model -> Text
modelImport moduleName path model =
  let modName = schemaModulePrefix moduleName <> modelName model
      rels =
        [ relName (psRel step)
          | step <- jpSteps path,
            modelName (psFrom step) == modelName model
        ]
   in case rels of
        [] ->
          "import "
            <> modName
            <> " ("
            <> modelName model
            <> "Row (..))"
        _ ->
          "import "
            <> modName
            <> " ("
            <> T.intercalate ", " (modelName model <> "Row (..)" : rels)
            <> ")"

qualifiedImport :: Text -> Model -> Text
qualifiedImport moduleName model =
  "import qualified "
    <> schemaModulePrefix moduleName
    <> modelName model
    <> " as "
    <> modelName model

schemaModulePrefix :: Text -> Text
schemaModulePrefix moduleName =
  case T.breakOnEnd "." moduleName of
    (prefix, _) | not (T.null prefix) -> prefix
    _ -> ""

enumImports :: Text -> Schema -> ModelInclude -> [Text]
enumImports prefix schema incl =
  [ enumImportLine prefix e
    | e <- schemaEnums schema,
      enumName e `elem` usedEnumNames schema incl
  ]

usedEnumNames :: Schema -> ModelInclude -> [Text]
usedEnumNames schema incl =
  [ name
    | f <- includeFields schema incl,
      TyEnum name <- [fieldType f]
  ]

includeFields :: Schema -> ModelInclude -> [FieldSpec]
includeFields schema incl =
  let path = includeLongestJoinPath schema incl
   in concat
        [ fieldsAtPathIndex path idx model
          | (idx, model) <- zip [0 ..] (joinPathModels path)
        ]

fieldsAtPathIndex :: JoinPath -> Int -> Model -> [FieldSpec]
fieldsAtPathIndex path idx model =
  case idx of
    0 -> modelFields model
    _ ->
      let step = jpSteps path !! (idx - 1)
       in filter (not . isRelationFkField (psRel step)) (modelFields model)

isRelationFkField :: RelationSpec -> FieldSpec -> Bool
isRelationFkField rel f = fieldName f == relForeignField rel

collectIncludeTypes :: Schema -> ModelInclude -> [IncludeTypeDecl]
collectIncludeTypes schema incl =
  nested ++ [rootDecl]
  where
    root = lookupModel schema (includeRootModel incl)
    rootDecl =
      IncludeTypeDecl
        { itdName = includeName incl,
          itdParent = root,
          itdEdges = includeTree incl
        }
    nested = collectNested schema root (includeTree incl)

collectNested :: Schema -> Model -> [IncludeTree] -> [IncludeTypeDecl]
collectNested schema current = concatMap go
  where
    go edge =
      let rel = lookupRelation current (includeRelation edge)
          child = lookupModel schema (relToModel rel)
          kids = includeChildren edge
          deeper = collectNested schema child kids
          self =
            [ IncludeTypeDecl
                { itdName = modelName child <> "Include",
                  itdParent = child,
                  itdEdges = kids
                }
              | not (null kids)
            ]
       in deeper ++ self

emitTypeDecl :: Schema -> IncludeTypeDecl -> Text
emitTypeDecl schema IncludeTypeDecl {itdName, itdParent, itdEdges} =
  T.unlines
    [ keyword <> " " <> itdName <> " = " <> itdName,
      "  { " <> T.intercalate ",\n    " (map (emitField schema itdParent) itdEdges),
      "  }",
      "  deriving (Show, Eq)"
    ]
  where
    keyword = if length itdEdges == 1 then "newtype" else "data"

emitField :: Schema -> Model -> IncludeTree -> Text
emitField schema parent edge =
  name <> " :: " <> ty
  where
    rel = lookupRelation parent (includeRelation edge)
    child = lookupModel schema (relToModel rel)
    name = includeFieldName parent rel
    ty =
      if null (includeChildren edge)
        then "Bool"
        else "Maybe " <> modelName child <> "Include"

collectResultTypes :: Schema -> ModelInclude -> [IncludeTypeDecl]
collectResultTypes schema incl =
  nested ++ [rootDecl]
  where
    root = lookupModel schema (includeRootModel incl)
    rootDecl =
      IncludeTypeDecl
        { itdName = resultTypeName schema root (includeTree incl),
          itdParent = root,
          itdEdges = includeTree incl
        }
    nested =
      [ IncludeTypeDecl
          { itdName = resultTypeName schema (itdParent d) (itdEdges d),
            itdParent = itdParent d,
            itdEdges = itdEdges d
          }
        | d <- collectNested schema root (includeTree incl)
      ]

resultTypeName :: Schema -> Model -> [IncludeTree] -> Text
resultTypeName _schema model edges =
  modelName model
    <> "With"
    <> T.concat (map (upperFirst . fieldOf) edges)
  where
    fieldOf edge =
      includeFieldName model (lookupRelation model (includeRelation edge))

emitResultTypeDecl :: Schema -> IncludeTypeDecl -> Text
emitResultTypeDecl schema IncludeTypeDecl {itdName, itdParent, itdEdges} =
  T.unlines
    [ "data " <> itdName <> " = " <> itdName,
      "  { " <> T.intercalate ",\n    " fields,
      "  }",
      "  deriving (Show, Eq)"
    ]
  where
    rootField =
      lowerFirst (modelName itdParent) <> " :: " <> modelName itdParent <> "Row"
    fields = rootField : map (emitResultField schema itdParent) itdEdges

emitResultField :: Schema -> Model -> IncludeTree -> Text
emitResultField schema parent edge =
  name <> " :: " <> ty
  where
    rel = lookupRelation parent (includeRelation edge)
    child = lookupModel schema (relToModel rel)
    name = includeFieldName parent rel
    kids = includeChildren edge
    ty
      | not (null kids) =
          "[" <> resultTypeName schema child kids <> "]"
      | RelHasMany <- relKind rel =
          "[" <> modelName child <> "Row]"
      | otherwise =
          "Maybe " <> modelName child <> "Row"

includeFieldName :: Model -> RelationSpec -> Text
includeFieldName parent rel =
  case T.stripPrefix (lowerFirst (modelName parent)) (relName rel) of
    Just rest | not (T.null rest) -> lowerFirst rest
    _ -> lowerFirst (relToModel rel)

lookupModel :: Schema -> Text -> Model
lookupModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just m -> m
    Nothing -> error $ "emit Include: unknown model " <> T.unpack name

lookupRelation :: Model -> Text -> RelationSpec
lookupRelation model name =
  case find ((== name) . relName) (modelRelations model) of
    Just r -> r
    Nothing ->
      error $
        "emit Include: unknown relation "
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