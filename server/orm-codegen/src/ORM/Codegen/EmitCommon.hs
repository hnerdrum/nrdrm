{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.EmitCommon
  ( fieldBinder,
    hsType,
    primaryKeyField,
    includeFieldName,
    createTypeName,
    updateTypeName,
    tableTypeName,
    rowTypeName,
    selectTypeName,
    pickedTypeName,
    selectDefaultName,
    selectColumnsFnName,
    parsePickedName,
    toPickedName,
    resultTypeName,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.IR
import ORM.Codegen.Lookup (lookupRelation)
import ORM.Codegen.TextUtil (lowerFirst, upperFirst)

fieldBinder :: Model -> FieldSpec -> Text
fieldBinder model f =
  lowerFirst (modelName model) <> upperFirst (fieldName f)

hsType :: FieldType -> Text
hsType TyText = "Text"
hsType TyUuid = "UUID"
hsType TyInt = "Int"
hsType TyTimestamptz = "UTCTime"
hsType TyBool = "Bool"
hsType (TyEnum name) = name

primaryKeyField :: Model -> FieldSpec
primaryKeyField model =
  case filter fieldIsPrimaryKey (modelFields model) of
    [f] -> f
    _ ->
      error $
        "ORM.Codegen.EmitCommon: model "
          <> T.unpack (modelName model)
          <> " must have exactly one primary key"

includeFieldName :: Model -> RelationSpec -> Text
includeFieldName parent rel =
  case T.stripPrefix (lowerFirst (modelName parent)) (relName rel) of
    Just rest | not (T.null rest) -> lowerFirst rest
    _ -> lowerFirst (relToModel rel)

createTypeName :: Model -> Text
createTypeName model = modelName model <> "Create"

updateTypeName :: Model -> Text
updateTypeName model = modelName model <> "Update"

tableTypeName :: Model -> Text
tableTypeName model = modelName model <> "Table"

rowTypeName :: Model -> Text
rowTypeName model = modelName model <> "Row"

selectTypeName :: Model -> Text
selectTypeName model = modelName model <> "Select"

pickedTypeName :: Model -> Text
pickedTypeName model = modelName model <> "Picked"

selectDefaultName :: Model -> Text
selectDefaultName model = lowerFirst (modelName model) <> "Select"

selectColumnsFnName :: Model -> Text
selectColumnsFnName model = lowerFirst (modelName model) <> "SelectColumns"

parsePickedName :: Model -> Text
parsePickedName model = "parse" <> modelName model <> "Picked"

toPickedName :: Model -> Text
toPickedName model = "to" <> modelName model <> "Picked"

resultTypeName :: Schema -> Model -> [IncludeTree] -> Text
resultTypeName _schema model edges =
  modelName model
    <> "With"
    <> T.concat (map (upperFirst . fieldOf) edges)
  where
    fieldOf edge =
      includeFieldName model (lookupRelation model (includeRelation edge))
