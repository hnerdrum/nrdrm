{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.Include
  ( emitIncludeADTs,
    emitIncludesJoin,
    emitShallowJoinBuilder,
    emitShallowBuildJoinChain,
    emitIncludeModule,
  )
where

import Data.Char (toLower)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.Emit.FlatRow
  ( ShallowJoin (..),
    emitShallowColumnList,
    emitShallowFlatJoinRow,
    modelAlias,
    shallowColumnListName,
    shallowJoin,
    shallowJoinRowName,
  )
import ORM.Codegen.IR

data IncludeTypeDecl = IncludeTypeDecl
  { itdName :: Text,
    itdParent :: Model,
    itdEdges :: [IncludeTree]
  }

emitIncludeADTs :: Schema -> ModelInclude -> Text
emitIncludeADTs schema incl =
  T.intercalate "\n" $
    map (emitTypeDecl schema) (collectIncludeTypes schema incl)

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

emitShallowJoinBuilder :: Schema -> ModelInclude -> Text
emitShallowJoinBuilder schema incl =
  case relKind sjRel of
    RelBelongsTo ->
      error "emitShallowJoinBuilder: BelongsTo root edge not supported yet"
    RelHasMany ->
      T.unlines
        [ builderName <> " :: JoinChain.JoinChain " <> rootTable,
          builderName <> " =",
          "  JoinChain.selectColumns " <> colsName <> " $",
          "    JoinChain.buildJoinChainFromHasMany "
            <> relName sjRel
            <> " \""
            <> modelAlias sjRoot
            <> "\" \""
            <> modelAlias sjChild
            <> "\""
        ]
  where
    ShallowJoin {sjRoot, sjChild, sjRel} = shallowJoin schema incl
    builderName = shallowJoinBuilderName sjRoot sjChild
    rootTable = modelName sjRoot <> "Table"
    colsName = shallowColumnListName sjRoot sjChild

emitShallowBuildJoinChain :: Schema -> ModelInclude -> Text
emitShallowBuildJoinChain schema incl =
  T.unlines
    [ "instance BuildJoinChain " <> rootTable <> " " <> includeName incl <> " where",
      "  type JoinFlatRow " <> includeName incl <> " = " <> rowName,
      "  buildJoinChain _ = " <> builderName
    ]
  where
    ShallowJoin {sjRoot, sjChild} = shallowJoin schema incl
    rootTable = modelName sjRoot <> "Table"
    rowName = shallowJoinRowName sjRoot sjChild
    builderName = shallowJoinBuilderName sjRoot sjChild

shallowJoinBuilderName :: Model -> Model -> Text
shallowJoinBuilderName root child =
  "build" <> modelName root <> modelName child <> "Join"

emitIncludeModule :: Text -> Schema -> ModelInclude -> Text
emitIncludeModule moduleName schema incl =
  T.unlines $
    concat
      [ includePragmas,
        [ "module " <> moduleName,
          emitIncludeExports schema incl,
          "where",
          "",
          emitIncludeImports schema incl,
          ""
        ],
        [ emitIncludeADTs schema incl,
          emitIncludesJoin schema incl,
          emitShallowFlatJoinRow schema incl,
          emitShallowColumnList schema incl,
          emitShallowJoinBuilder schema incl,
          emitShallowBuildJoinChain schema incl
        ]
      ]

includePragmas :: [Text]
includePragmas =
  [ "{-# LANGUAGE FlexibleContexts #-}",
    "{-# LANGUAGE TypeFamilies #-}",
    ""
  ]

emitIncludeExports :: Schema -> ModelInclude -> Text
emitIncludeExports schema incl =
  "  ( "
    <> T.intercalate ",\n    " items
    <> "\n  )"
  where
    ShallowJoin {sjRoot, sjChild} = shallowJoin schema incl
    edge = case includeTree incl of
      (e : _) -> e
      [] -> error "emitIncludeExports: empty include tree"
    nestedExport =
      [ modelName sjChild <> "Include (..)"
        | not (null (includeChildren edge))
      ]
    items =
      [includeName incl <> " (..)"]
        ++ nestedExport
        ++ [ shallowJoinRowName sjRoot sjChild <> " (..)",
             shallowColumnListName sjRoot sjChild,
             shallowJoinBuilderName sjRoot sjChild
           ]

emitIncludeImports :: Schema -> ModelInclude -> Text
emitIncludeImports schema incl =
  T.intercalate "\n" $
    filter
      (not . T.null)
      [ "import Data.Maybe (isJust)",
        "import Data.Text (Text)",
        if needsUuid then "import Data.UUID (UUID)" else "",
        if needsTime then "import Data.Time (UTCTime)" else "",
        "import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)",
        "import ORM.Include (BuildJoinChain (..), IncludesJoin (..))",
        "import qualified ORM.JoinChain as JoinChain",
        "import "
          <> rootMod
          <> " ("
          <> modelName sjRoot
          <> "Table, "
          <> relName sjRel
          <> ")",
        "import qualified " <> rootMod <> " as " <> modelName sjRoot,
        "import qualified " <> childMod <> " as " <> modelName sjChild
      ]
  where
    ShallowJoin {sjRoot, sjChild, sjRel, sjRootFields, sjChildFields} =
      shallowJoin schema incl
    rootMod = "Schema." <> modelName sjRoot
    childMod = "Schema." <> modelName sjChild
    allFields = sjRootFields ++ sjChildFields
    needsUuid = any ((== TyUuid) . fieldType) allFields
    needsTime = any ((== TyTimestamptz) . fieldType) allFields

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