{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.Schema
  ( emitModelModule,
    emitHasMany,
    emitBelongsTo,
  )
where

import Data.Char (toLower, toUpper)
import Data.List (find)
import Data.Maybe (isJust, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.IR

emitModelModule :: Text -> Schema -> Model -> Text
emitModelModule moduleName schema model =
  T.unlines $
    concat
      [ pragmas,
        [ "module " <> moduleName,
          emitExports model,
          "where",
          "",
          imports moduleName schema model,
          "",
          "data " <> tableName_ <> " = " <> tableName_,
          "",
          "type instance PrimaryKeyType " <> tableName_ <> " = " <> pkHsType model,
          "",
          "instance Entity " <> tableName_ <> " where",
          "  tableName = \"" <> modelTable model <> "\"",
          "  primaryKey = " <> fieldBinder model pkField,
          "",
          emitInsertable model,
          "",
          emitUpdatable model,
          "",
          emitRow model,
          "",
          emitCreate model,
          "",
          emitUpdate model,
          "",
          emitFromRow model,
          ""
        ],
        concatMap (emitFieldDecl model) (modelFields model),
        map (emitHasMany schema) (hasManyRelations model),
        map (emitBelongsTo schema) (belongsToRelations model)
      ]
  where
    tableName_ = tableTypeName model
    pkField = primaryKeyField model

emitExports :: Model -> Text
emitExports model =
  "  ( "
    <> T.intercalate ",\n    " items
    <> "\n  )"
  where
    items =
      [ tableTypeName model <> " (..)",
        rowTypeName model <> " (..)",
        createTypeName model <> " (..)",
        updateTypeName model <> " (..)"
      ]
        ++ map (fieldBinder model) (modelFields model)
        ++ map relName (hasManyRelations model)
        ++ map relName (belongsToRelations model)

pragmas :: [Text]
pragmas =
  [ "{-# LANGUAGE AllowAmbiguousTypes #-}",
    "{-# LANGUAGE DuplicateRecordFields #-}",
    "{-# LANGUAGE NoFieldSelectors #-}",
    "{-# LANGUAGE OverloadedRecordDot #-}",
    "{-# LANGUAGE TypeApplications #-}",
    ""
  ]

imports :: Text -> Schema -> Model -> Text
imports moduleName schema model =
  T.intercalate "\n" $
    filter
      (not . T.null)
      [ if needsText model then "import Data.Text (Text)" else "",
        if needsTime model then "import Data.Time (UTCTime)" else "",
        if needsUuid model then "import Data.UUID (UUID)" else "",
        "import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)",
        "import ORM.Core",
        insertImport model,
        updateImport model,
        relationImport model
      ]
      ++ enumImports schema model
      ++ relationModelImports moduleName schema model

enumImports :: Schema -> Model -> [Text]
enumImports schema model =
  [ "import " <> imp <> " (" <> enumName e <> ")"
    | e <- schemaEnums schema,
      enumName e `elem` usedEnumNames,
      Just imp <- [enumImport e]
  ]
  where
    usedEnumNames =
      [ name
        | f <- modelFields model,
          TyEnum name <- [fieldType f]
      ]

relationModelImports :: Text -> Schema -> Model -> [Text]
relationModelImports moduleName schema model =
  concatMap hasManyImport (hasManyRelations model)
    ++ concatMap belongsToImport (belongsToRelations model)
  where
    hasManyImport rel =
      let child = lookupModel schema (relToModel rel)
          foreignField = lookupField child (relForeignField rel)
          childMod = siblingModule moduleName child
       in [ "import "
              <> childMod
              <> " ("
              <> tableTypeName child
              <> ", "
              <> fieldBinder child foreignField
              <> ")"
          ]
    belongsToImport rel =
      let parent = lookupModel schema (relToModel rel)
          parentMod = siblingModule moduleName parent
       in [ "import " <> parentMod <> " (" <> tableTypeName parent <> ")",
            "import qualified " <> parentMod <> " as " <> modelName parent
          ]

siblingModule :: Text -> Model -> Text
siblingModule moduleName model =
  case T.breakOnEnd "." moduleName of
    (prefix, _) | not (T.null prefix) -> prefix <> modelName model
    _ -> modelName model

insertImport :: Model -> Text
insertImport model =
  let needsNullable = any fieldNullable (modelFields model)
      needsMaybe = any ((== CreateMaybe) . createKind) (modelFields model)
      parts =
        ["Insertable (..)", "emptyInsert"]
          ++ ["set" | hasRequiredCreateField model]
          ++ ["setMaybe" | needsMaybe]
          ++ ["setNullable" | needsNullable]
   in "import ORM.Insert (" <> T.intercalate ", " parts <> ")"

updateImport :: Model -> Text
updateImport model =
  let needsNullable = any fieldNullable (updateFields model)
      needsMaybe = (not . all fieldNullable) (updateFields model)
      parts =
        ["Updatable (..)", "emptyUpdate"]
          ++ ["setFieldMaybe" | needsMaybe]
          ++ ["setFieldNullable" | needsNullable]
   in "import ORM.Update (" <> T.intercalate ", " parts <> ")"

relationImport :: Model -> Text
relationImport model =
  case (needsHasMany model, needsBelongsTo model) of
    (False, False) -> ""
    (True, False) -> "import ORM.Relation (HasMany (..), JoinType (..))"
    (False, True) -> "import ORM.Relation (BelongsTo (..), JoinType (..))"
    (True, True) -> "import ORM.Relation (HasMany (..), BelongsTo (..), JoinType (..))"

needsTime :: Model -> Bool
needsTime = any ((== TyTimestamptz) . fieldType) . modelFields

needsText :: Model -> Bool
needsText = any (isTextType . fieldType) . modelFields
  where
    isTextType TyText = True
    isTextType _ = False

needsUuid :: Model -> Bool
needsUuid = any (isUuidType . fieldType) . modelFields
  where
    isUuidType TyUuid = True
    isUuidType _ = False

hasRequiredCreateField :: Model -> Bool
hasRequiredCreateField =
  any (\f -> createKind f == CreateRequired) . modelFields

needsHasMany :: Model -> Bool
needsHasMany = not . null . hasManyRelations

hasManyRelations :: Model -> [RelationSpec]
hasManyRelations =
  filter ((== RelHasMany) . relKind) . modelRelations

needsBelongsTo :: Model -> Bool
needsBelongsTo = not . null . belongsToRelations

belongsToRelations :: Model -> [RelationSpec]
belongsToRelations =
  filter ((== RelBelongsTo) . relKind) . modelRelations

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

primaryKeyField :: Model -> FieldSpec
primaryKeyField model =
  case filter fieldIsPrimaryKey (modelFields model) of
    [f] -> f
    _ -> error "emitModelModule: model must have exactly one primary key"

pkHsType :: Model -> Text
pkHsType model = hsType (fieldType (primaryKeyField model))

hsType :: FieldType -> Text
hsType TyText = "Text"
hsType TyUuid = "UUID"
hsType TyInt = "Int"
hsType TyTimestamptz = "UTCTime"
hsType (TyEnum name) = name

rowHsType :: FieldSpec -> Text
rowHsType f
  | fieldNullable f = "Maybe " <> hsType (fieldType f)
  | otherwise = hsType (fieldType f)

data CreateKind = CreateMaybe | CreateNullable | CreateRequired
  deriving (Eq)

createKind :: FieldSpec -> CreateKind
createKind f
  | fieldIsPrimaryKey f && isJust (fieldDefault f) = CreateMaybe
  | fieldIsPrimaryKey f = CreateRequired
  | isJust (fieldDefault f) = CreateMaybe
  | fieldNullable f = CreateNullable
  | otherwise = CreateRequired

createHsType :: FieldSpec -> Text
createHsType f = case createKind f of
  CreateMaybe -> "Maybe " <> hsType (fieldType f)
  CreateNullable -> "NullableValue " <> hsType (fieldType f)
  CreateRequired -> hsType (fieldType f)

updateFields :: Model -> [FieldSpec]
updateFields = filter (not . fieldIsPrimaryKey) . modelFields

updateHsType :: FieldSpec -> Text
updateHsType f
  | fieldNullable f = "NullableValue " <> hsType (fieldType f)
  | otherwise = "Maybe " <> hsType (fieldType f)

emitRow :: Model -> Text
emitRow model =
  T.unlines
    [ "data " <> rowTypeName model <> " = " <> rowTypeName model,
      "  { " <> T.intercalate ",\n    " (map rowField (modelFields model)),
      "  }",
      "  deriving (Show, Eq)"
    ]
  where
    rowField f = fieldName f <> " :: " <> rowHsType f

emitCreate :: Model -> Text
emitCreate model =
  T.unlines
    [ "data " <> createTypeName model <> " = " <> createTypeName model,
      "  { " <> T.intercalate ",\n    " (map createField (modelFields model)),
      "  }",
      "  deriving (Show, Eq)"
    ]
  where
    createField f = fieldName f <> " :: " <> createHsType f

emitUpdate :: Model -> Text
emitUpdate model =
  T.unlines
    [ "data " <> updateTypeName model <> " = " <> updateTypeName model,
      "  { " <> T.intercalate ",\n    " (map updateField (updateFields model)),
      "  }",
      "  deriving (Show, Eq)"
    ]
  where
    updateField f = fieldName f <> " :: " <> updateHsType f

emitFromRow :: Model -> Text
emitFromRow model =
  let n = length (modelFields model)
      fields = T.intercalate " <*> " (replicate n "field")
   in T.unlines
        [ "instance FromRow " <> rowTypeName model <> " where",
          "  fromRow = " <> rowTypeName model <> " <$> " <> fields
        ]

emitFieldDecl :: Model -> FieldSpec -> [Text]
emitFieldDecl model f =
  [ binder <> " :: Field " <> tableTypeName model <> " " <> hsType (fieldType f),
    binder <> " = Field \"" <> fieldName f <> "\" \"" <> fieldColumn f <> "\"",
    ""
  ]
  where
    binder = fieldBinder model f

emitInsertable :: Model -> Text
emitInsertable model =
  T.unlines
    [ "instance Insertable " <> tableTypeName model <> " where",
      "  type CreateInput " <> tableTypeName model <> " = " <> createTypeName model,
      "  toInsertBuilder input =",
      "    " <> body
    ]
  where
    fields = modelFields model
    body = foldr wrap ("emptyInsert @" <> tableTypeName model) fields
    wrap f inner = case createKind f of
      CreateNullable ->
        "setNullable " <> fieldBinder model f <> " input." <> fieldName f <> " $\n      " <> inner
      CreateMaybe ->
        "setMaybe " <> fieldBinder model f <> " input." <> fieldName f <> " $\n      " <> inner
      CreateRequired ->
        "set " <> fieldBinder model f <> " input." <> fieldName f <> " $\n      " <> inner

emitUpdatable :: Model -> Text
emitUpdatable model =
  T.unlines
    [ "instance Updatable " <> tableTypeName model <> " where",
      "  type UpdateInput " <> tableTypeName model <> " = " <> updateTypeName model,
      updatedAtLine,
      "  toUpdateBuilder input =",
      "    " <> body
    ]
  where
    fields = updateFields model
    body = foldr wrap ("emptyUpdate @" <> tableTypeName model) fields
    wrap f inner
      | fieldNullable f =
          "setFieldNullable " <> fieldBinder model f <> " input." <> fieldName f <> " $\n      " <> inner
      | otherwise =
          "setFieldMaybe " <> fieldBinder model f <> " input." <> fieldName f <> " $\n      " <> inner
    updatedAtLine =
      case mapMaybe updatedAtBinder (modelFields model) of
        (b : _) -> "  updatedAtField = Just " <> b
        [] -> "  updatedAtField = Nothing"
    updatedAtBinder f
      | fieldUpdatedAt f = Just (fieldBinder model f)
      | otherwise = Nothing

emitHasMany :: Schema -> RelationSpec -> Text
emitHasMany schema rel =
  case relKind rel of
    RelBelongsTo ->
      error "emitHasMany: expected RelHasMany"
    RelHasMany ->
      T.unlines
        [ name <> " :: HasMany " <> parentTable <> " " <> childTable <> " " <> keyTy,
          name <> " =",
          "  HasMany",
          "    { localKey = " <> localBinder <> ",",
          "      foreignKey = " <> foreignBinder <> ",",
          "      joinType = " <> joinTy,
          "    }"
        ]
  where
    name = relName rel
    parent = lookupModel schema (relFromModel rel)
    child = lookupModel schema (relToModel rel)
    parentTable = tableTypeName parent
    childTable = tableTypeName child
    localField = lookupField parent (relLocalField rel)
    foreignField = lookupField child (relForeignField rel)
    localBinder = fieldBinder parent localField
    foreignBinder = fieldBinder child foreignField
    keyTy = hsType (fieldType localField)
    joinTy = emitJoinType (relJoin rel)

emitBelongsTo :: Schema -> RelationSpec -> Text
emitBelongsTo schema rel =
  case relKind rel of
    RelHasMany ->
      error "emitBelongsTo: expected RelBelongsTo"
    RelBelongsTo ->
      T.unlines
        [ name <> " :: BelongsTo " <> childTable <> " " <> parentTable <> " " <> keyTy,
          name <> " =",
          "  BelongsTo",
          "    { foreignKey = " <> foreignBinder <> ",",
          "      references = " <> referencesBinder <> ",",
          "      joinType = " <> joinTy,
          "    }"
        ]
  where
    name = relName rel
    child = lookupModel schema (relFromModel rel)
    parent = lookupModel schema (relToModel rel)
    childTable = tableTypeName child
    parentTable = tableTypeName parent
    -- IR: relForeignField = FK on child; relLocalField = referenced field on parent
    foreignField = lookupField child (relForeignField rel)
    referencedField = lookupField parent (relLocalField rel)
    foreignBinder = fieldBinder child foreignField
    referencesBinder =
      modelName parent <> "." <> fieldBinder parent referencedField
    keyTy = hsType (fieldType foreignField)
    joinTy = emitJoinType (relJoin rel)

emitJoinType :: JoinKind -> Text
emitJoinType JoinLeft = "LeftJoin"
emitJoinType JoinInner = "InnerJoin"
emitJoinType JoinRight = "RightJoin"

lookupModel :: Schema -> Text -> Model
lookupModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just m -> m
    Nothing -> error $ "emit: unknown model " <> T.unpack name

lookupField :: Model -> Text -> FieldSpec
lookupField model name =
  case find ((== name) . fieldName) (modelFields model) of
    Just f -> f
    Nothing ->
      error $
        "emit: unknown field "
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
