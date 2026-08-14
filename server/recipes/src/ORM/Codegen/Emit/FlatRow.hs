{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.FlatRow
  ( emitShallowFlatJoinRow,
    emitShallowColumnList,
    emitDeepFlatJoinRow,
    emitDeepColumnList,
    shallowJoinRowName,
    shallowColumnListName,
    deepJoinRowName,
    deepColumnListName,
    shallowJoin,
    ShallowJoin (..),
    deepJoin,
    DeepJoin (..),
    modelAlias,
    rootJoinAlias,
    childJoinAlias,
    grandJoinAlias,
    columnExprWithAlias,
  )
where

import Data.Char (isUpper, toLower, toUpper)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.IR

emitShallowFlatJoinRow :: Schema -> ModelInclude -> Text
emitShallowFlatJoinRow schema incl =
  let ShallowJoin {sjRoot, sjChild, sjRootFields, sjChildFields} =
        shallowJoin schema incl
      rowName = shallowJoinRowName sjRoot sjChild
      allFields =
        map (flatField sjRoot False) sjRootFields
          ++ map (flatField sjChild True) sjChildFields
   in T.unlines
        [ "data " <> rowName <> " = " <> rowName,
          "  { " <> T.intercalate ",\n    " allFields,
          "  }",
          "  deriving (Show, Eq)",
          "",
          "instance FromRow " <> rowName <> " where",
          "  fromRow = " <> rowName <> " <$> " <> fromRowBody (length allFields)
        ]

emitShallowColumnList :: Schema -> ModelInclude -> Text
emitShallowColumnList schema incl =
  let ShallowJoin {sjRoot, sjChild, sjRootFields, sjChildFields} =
        shallowJoin schema incl
      name = shallowColumnListName sjRoot sjChild
      cols =
        map (columnExprWithAlias (rootJoinAlias sjRoot) sjRoot) sjRootFields
          ++ map (columnExprWithAlias (childJoinAlias sjRoot sjChild) sjChild) sjChildFields
   in T.unlines
        [ name <> " :: [Text]",
          name <> " =",
          "  [ " <> T.intercalate ",\n    " cols,
          "  ]"
        ]

emitDeepFlatJoinRow :: Schema -> ModelInclude -> Text
emitDeepFlatJoinRow schema incl =
  let DeepJoin {djRoot, djChild, djGrand, djRootFields, djChildFields, djGrandFields} =
        deepJoin schema incl
      rowName = deepJoinRowName djRoot djChild djGrand
      allFields =
        map (flatField djRoot False) djRootFields
          ++ map (flatField djChild True) djChildFields
          ++ map (flatField djGrand True) djGrandFields
   in T.unlines
        [ "data " <> rowName <> " = " <> rowName,
          "  { " <> T.intercalate ",\n    " allFields,
          "  }",
          "  deriving (Show, Eq)",
          "",
          "instance FromRow " <> rowName <> " where",
          "  fromRow = " <> rowName <> " <$> " <> fromRowBody (length allFields)
        ]

emitDeepColumnList :: Schema -> ModelInclude -> Text
emitDeepColumnList schema incl =
  let DeepJoin {djRoot, djChild, djGrand, djGrandFields} = deepJoin schema incl
      name = deepColumnListName djRoot djChild djGrand
      shallowName = shallowColumnListName djRoot djChild
      grandCols =
        map
          (columnExprWithAlias (grandJoinAlias djRoot djChild djGrand) djGrand)
          djGrandFields
   in T.unlines
        [ name <> " :: [Text]",
          name <> " =",
          "  " <> shallowName,
          "    ++ [ " <> T.intercalate ",\n         " grandCols,
          "       ]"
        ]

data DeepJoin = DeepJoin
  { djRoot :: Model,
    djChild :: Model,
    djGrand :: Model,
    djChildRel :: RelationSpec,
    djGrandRel :: RelationSpec,
    djRootFields :: [FieldSpec],
    djChildFields :: [FieldSpec],
    djGrandFields :: [FieldSpec]
  }

deepJoin :: Schema -> ModelInclude -> DeepJoin
deepJoin schema incl =
  case includeTree incl of
    [] ->
      error $
        "deepJoin: include "
          <> T.unpack (includeName incl)
          <> " has empty tree"
    (edge : _) ->
      case includeChildren edge of
        [] ->
          error $
            "deepJoin: include "
              <> T.unpack (includeName incl)
              <> " has no nested child edge"
        (childEdge : _) ->
          let root = lookupModel schema (includeRootModel incl)
              childRel = lookupRelation root (includeRelation edge)
              child = lookupModel schema (relToModel childRel)
              grandRel = lookupRelation child (includeRelation childEdge)
              grand = lookupModel schema (relToModel grandRel)
           in DeepJoin
                { djRoot = root,
                  djChild = child,
                  djGrand = grand,
                  djChildRel = childRel,
                  djGrandRel = grandRel,
                  djRootFields = modelFields root,
                  djChildFields =
                    filter (not . isRelationFk childRel) (modelFields child),
                  djGrandFields =
                    filter (not . isRelationFk grandRel) (modelFields grand)
                }

deepJoinRowName :: Model -> Model -> Model -> Text
deepJoinRowName root child grand =
  modelName root <> modelName child <> modelName grand <> "JoinRow"

deepColumnListName :: Model -> Model -> Model -> Text
deepColumnListName root child grand =
  lowerFirst (modelName root) <> modelName child <> modelName grand <> "Columns"

data ShallowJoin = ShallowJoin
  { sjRoot :: Model,
    sjChild :: Model,
    sjRel :: RelationSpec,
    sjRootFields :: [FieldSpec],
    sjChildFields :: [FieldSpec]
  }

shallowJoin :: Schema -> ModelInclude -> ShallowJoin
shallowJoin schema incl =
  case includeTree incl of
    [] ->
      error $
        "shallowJoin: include "
          <> T.unpack (includeName incl)
          <> " has empty tree"
    (edge : _) ->
      let root = lookupModel schema (includeRootModel incl)
          rel = lookupRelation root (includeRelation edge)
          child = lookupModel schema (relToModel rel)
       in ShallowJoin
            { sjRoot = root,
              sjChild = child,
              sjRel = rel,
              sjRootFields = modelFields root,
              sjChildFields =
                filter (not . isRelationFk rel) (modelFields child)
            }

shallowColumnListName :: Model -> Model -> Text
shallowColumnListName root child =
  lowerFirst (modelName root) <> modelName child <> "Columns"

columnExprWithAlias :: Text -> Model -> FieldSpec -> Text
columnExprWithAlias alias model f =
  "JoinChain.col \""
    <> alias
    <> "\" "
    <> modelName model
    <> "."
    <> fieldBinder model f

modelAlias :: Model -> Text
modelAlias = rootJoinAlias

rootJoinAlias :: Model -> Text
rootJoinAlias model = T.toLower (T.take 1 (modelName model))

childJoinAlias :: Model -> Model -> Text
childJoinAlias root child =
  let rootAlias = rootJoinAlias root
   in if rootAlias == T.toLower (T.take 1 (modelName child))
        then abbrevCamelAlias (modelName child)
        else T.toLower (T.take 1 (modelName child))

grandJoinAlias :: Model -> Model -> Model -> Text
grandJoinAlias root child grand =
  let taken = [rootJoinAlias root, childJoinAlias root child]
      first = T.toLower (T.take 1 (modelName grand))
   in if first `elem` taken
        then abbrevCamelAlias (modelName grand)
        else first

abbrevCamelAlias :: Text -> Text
abbrevCamelAlias name =
  case T.uncons name of
    Nothing -> name
    Just (c, rest) ->
      case T.find isUpper rest of
        Just u -> T.cons (toLower c) (T.singleton (toLower u))
        Nothing -> T.singleton (toLower c)

shallowJoinRowName :: Model -> Model -> Text
shallowJoinRowName root child =
  modelName root <> modelName child <> "JoinRow"

flatField :: Model -> Bool -> FieldSpec -> Text
flatField model asJoinSide f =
  binder <> " :: " <> ty
  where
    binder = fieldBinder model f
    base = hsType (fieldType f)
    asMaybe = asJoinSide || fieldNullable f
    ty = if asMaybe then "Maybe " <> base else base

isRelationFk :: RelationSpec -> FieldSpec -> Bool
isRelationFk rel f = fieldName f == relForeignField rel

fromRowBody :: Int -> Text
fromRowBody n =
  T.intercalate " <*> " (replicate n "field")

fieldBinder :: Model -> FieldSpec -> Text
fieldBinder model f =
  lowerFirst (modelName model) <> upperFirst (fieldName f)

hsType :: FieldType -> Text
hsType TyText = "Text"
hsType TyUuid = "UUID"
hsType TyInt = "Int"
hsType TyTimestamptz = "UTCTime"
hsType (TyEnum name) = name

lookupModel :: Schema -> Text -> Model
lookupModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just m -> m
    Nothing -> error $ "emit FlatRow: unknown model " <> T.unpack name

lookupRelation :: Model -> Text -> RelationSpec
lookupRelation model name =
  case find ((== name) . relName) (modelRelations model) of
    Just r -> r
    Nothing ->
      error $
        "emit FlatRow: unknown relation "
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