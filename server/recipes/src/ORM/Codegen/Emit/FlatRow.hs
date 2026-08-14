{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.FlatRow
  ( emitShallowFlatJoinRow,
    emitShallowColumnList,
    shallowJoinRowName,
    shallowColumnListName,
    shallowJoin,
    ShallowJoin (..),
    modelAlias,
  )
where

import Data.Char (toLower, toUpper)
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
        map (columnExpr sjRoot) sjRootFields
          ++ map (columnExpr sjChild) sjChildFields
   in T.unlines
        [ name <> " :: [Text]",
          name <> " =",
          "  [ " <> T.intercalate ",\n    " cols,
          "  ]"
        ]

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

columnExpr :: Model -> FieldSpec -> Text
columnExpr model f =
  "JoinChain.col \""
    <> modelAlias model
    <> "\" "
    <> modelName model
    <> "."
    <> fieldBinder model f

modelAlias :: Model -> Text
modelAlias model =
  T.toLower (T.take 1 (modelName model))

shallowJoinRowName :: Model -> Model -> Text
shallowJoinRowName root child =
  modelName root <> modelName child <> "JoinRow"

flatField :: Model -> Bool -> FieldSpec -> Text
flatField model asMaybe f =
  binder <> " :: " <> ty
  where
    binder = fieldBinder model f
    base = hsType (fieldType f)
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