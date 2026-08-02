{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.Schema
  ( emitModelModule,
  )
where

import Data.Char (toLower, toUpper)
import Data.Maybe (isJust, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.IR

emitModelModule :: Text -> Model -> Text
emitModelModule moduleName model =
  T.unlines $
    concat
      [ pragmas,
        [ "module " <> moduleName,
          emitExports model,
          "where",
          "",
          imports model,
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
        concatMap (emitFieldDecl model) (modelFields model)
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

pragmas :: [Text]
pragmas =
  [ "{-# LANGUAGE AllowAmbiguousTypes #-}",
    "{-# LANGUAGE OverloadedRecordDot #-}",
    "{-# LANGUAGE TypeApplications #-}",
    ""
  ]

imports :: Model -> Text
imports model =
  T.intercalate "\n" $
    filter
      (not . T.null)
      [ "import Data.Text (Text)",
        if needsTime model then "import Data.Time (UTCTime)" else "",
        if needsUuid model then "import Data.UUID (UUID)" else "",
        "import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)",
        "import ORM.Core",
        insertImport model,
        updateImport model
      ]

insertImport :: Model -> Text
insertImport model =
  let needsNullable = any fieldNullable (modelFields model)
      needsMaybe = True
      parts =
        ["Insertable (..)", "emptyInsert"]
          ++ ["set" | hasRequiredCreateField model]
          ++ ["setMaybe" | needsMaybe]
          ++ ["setNullable" | needsNullable]
   in "import ORM.Insert (" <> T.intercalate ", " parts <> ")"

updateImport :: Model -> Text
updateImport model =
  let needsNullable = any fieldNullable (updateFields model)
      parts =
        ["Updatable (..)", "emptyUpdate"]
          ++ ["setFieldMaybe"]
          ++ ["setFieldNullable" | needsNullable]
   in "import ORM.Update (" <> T.intercalate ", " parts <> ")"

needsTime :: Model -> Bool
needsTime = any ((== TyTimestamptz) . fieldType) . modelFields

needsUuid :: Model -> Bool
needsUuid = any (isUuidType . fieldType) . modelFields
  where
    isUuidType TyUuid = True
    isUuidType _ = False

hasRequiredCreateField :: Model -> Bool
hasRequiredCreateField =
  any (\f -> createKind f == CreateRequired) . modelFields

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
  | fieldIsPrimaryKey f = CreateMaybe
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

lowerFirst :: Text -> Text
lowerFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toLower c) rest

upperFirst :: Text -> Text
upperFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toUpper c) rest
