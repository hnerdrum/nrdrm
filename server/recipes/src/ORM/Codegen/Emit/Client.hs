{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.Client
  ( emitSimpleClientModule,
    emitIncludeReadClientModule,
    emitRecipeClientModule,
  )
where

import Data.Char (toLower, toUpper)
import Data.List (find)
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
      emitUpdateFn model,
      "",
      emitFindAllFn model,
      "",
      emitFindUniqueFn model,
      "",
      emitFindUniqueOrErrorFn model,
      "",
      emitDeleteFn model
    ]

emitIncludeReadClientModule :: Text -> Schema -> ModelInclude -> Text
emitIncludeReadClientModule moduleName schema incl =
  T.unlines
    [ "{-# LANGUAGE TypeApplications #-}",
      "",
      "module " <> moduleName,
      emitIncludeReadExports schema incl,
      "where",
      "",
      "import Data.Pool (Pool)",
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
      "import "
        <> includeModule moduleName incl
        <> " ( "
        <> includeName incl
        <> " (..), "
        <> T.intercalate ", " includeTypeExports
        <> ", "
        <> resultTypeName schema root (includeTree incl)
        <> " (..))",
      "",
      emitFullIncludePreset schema incl,
      "",
      emitNoIncludePreset schema incl,
      "",
      emitIncludeFindAll root incl,
      "",
      emitIncludeFindMany root incl,
      "",
      emitIncludeFindUnique root incl,
      "",
      emitIncludeFindUniqueOrError root incl
    ]
  where
    root = lookupModel schema (includeRootModel incl)
    includeTypeExports =
      [ modelName child <> "Include (..)"
        | edge <- includeTree incl,
          let rel = lookupRelation root (includeRelation edge),
          let child = lookupModel schema (relToModel rel),
          not (null (includeChildren edge))
      ]

emitRecipeClientModule :: Text -> Schema -> ModelInclude -> Text
emitRecipeClientModule moduleName schema incl =
  T.unlines
    [ "{-# LANGUAGE TypeApplications #-}",
      "",
      "module " <> moduleName,
      emitRecipeExports schema incl,
      "where",
      "",
      "import Control.Monad (forM_)",
      "import Data.Maybe (mapMaybe)",
      "import Data.Pool (Pool)",
      "import Data.Time (UTCTime, getCurrentTime)",
      "import Data.UUID (UUID)",
      "import qualified Data.UUID.V4 as V4",
      "import Database.PostgreSQL.Simple (Connection)",
      "import Database.PostgreSQL.Simple.ToField (toField)",
      "import Database.Recipe",
      "  ( CreateRecipeIngredientInput (..),",
      "    CreateRecipeInput (..),",
      "    UpdateRecipeIngredientInput (..),",
      "    UpdateRecipeInput (..),",
      "  )",
      "import ORM.Core (NullableValue (..), fieldColumn)",
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
      "import "
        <> includeModule moduleName incl
        <> " ( "
        <> includeName incl
        <> " (..), "
        <> T.intercalate ", " includeTypeExports
        <> ", "
        <> resultTypeName schema root (includeTree incl)
        <> " (..))",
      "import "
        <> schemaModule moduleName child
        <> " ( "
        <> createTypeName child
        <> " (..), "
        <> tableTypeName child
        <> ", "
        <> deleteField
        <> ")",
      "import ORM.Transaction (transaction)",
      "import qualified ORM.Operations as Ops",
      "import ORM.Query (QueryBuilder)",
      "import qualified ORM.Update as Update",
      "",
      emitFullIncludePreset schema incl,
      "",
      emitNoIncludePreset schema incl,
      "",
      emitIncludeFindAll root incl,
      "",
      emitIncludeFindMany root incl,
      "",
      emitIncludeFindUnique root incl,
      "",
      emitIncludeFindUniqueOrError root incl,
      "",
      emitRecipeCreate root incl child,
      "",
      emitRecipeUpdate root incl child deleteField,
      "",
      emitRecipeDelete root,
      "",
      emitToRecipeCreate root,
      "",
      emitToRecipeUpdate root,
      "",
      emitToRecipeIngredientCreate child,
      "",
      emitToRecipeIngredientUpdate child
    ]
  where
    root = lookupModel schema (includeRootModel incl)
    child = hasManyChild schema root (head (includeTree incl))
    deleteField = fieldBinder child (primaryKeyField child)
    includeTypeExports =
      [ modelName nested <> "Include (..)"
        | edge <- includeTree incl,
          let rel = lookupRelation root (includeRelation edge),
          let nested = lookupModel schema (relToModel rel),
          not (null (includeChildren edge))
      ]

emitSimpleExports :: Text
emitSimpleExports =
  T.unlines
    [ "  ( create,",
      "    update,",
      "    findAll,",
      "    findUnique,",
      "    findUniqueOrError,",
      "    delete",
      "  )"
    ]

emitIncludeReadExports :: Schema -> ModelInclude -> Text
emitIncludeReadExports schema incl =
  T.unlines
    [ "  ( findAll,",
      "    findMany,",
      "    findUnique,",
      "    findUniqueOrError,",
      "    " <> fullPresetName schema incl <> ",",
      "    noInclude",
      "  )"
    ]

emitRecipeExports :: Schema -> ModelInclude -> Text
emitRecipeExports schema incl =
  T.unlines
    [ "  ( findAll,",
      "    findMany,",
      "    findUnique,",
      "    findUniqueOrError,",
      "    create,",
      "    update,",
      "    delete,",
      "    " <> fullPresetName schema incl <> ",",
      "    noInclude",
      "  )"
    ]

emitCreateFn :: Model -> Text
emitCreateFn model =
  T.unlines
    [ "create :: Pool Connection -> " <> createTypeName model <> " -> IO (Either ORMError " <> rowTypeName model <> ")",
      "create = Insert.insert @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitUpdateFn :: Model -> Text
emitUpdateFn model =
  T.unlines
    [ "update :: Pool Connection -> UUID -> " <> updateTypeName model <> " -> IO (Either ORMError " <> rowTypeName model <> ")",
      "update = Update.update @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindAllFn :: Model -> Text
emitFindAllFn model =
  T.unlines
    [ "findAll :: Pool Connection -> IO [" <> rowTypeName model <> "]",
      "findAll = Ops.findAll @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindUniqueFn :: Model -> Text
emitFindUniqueFn model =
  T.unlines
    [ "findUnique :: Pool Connection -> UUID -> IO (Maybe " <> rowTypeName model <> ")",
      "findUnique = Ops.findUnique @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitFindUniqueOrErrorFn :: Model -> Text
emitFindUniqueOrErrorFn model =
  T.unlines
    [ "findUniqueOrError :: Pool Connection -> UUID -> IO (Either ORMError " <> rowTypeName model <> ")",
      "findUniqueOrError = Ops.findUniqueOrError @" <> tableTypeName model <> " @" <> rowTypeName model
    ]

emitDeleteFn :: Model -> Text
emitDeleteFn model =
  T.unlines
    [ "delete :: Pool Connection -> UUID -> IO Int",
      "delete = Ops.delete @" <> tableTypeName model
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
    [ "findAll :: Pool Connection -> " <> includeName incl <> " -> IO [" <> includeResultName model incl <> "]",
      "findAll = Include.findAll @" <> tableTypeName model
    ]

emitIncludeFindMany :: Model -> ModelInclude -> Text
emitIncludeFindMany model incl =
  T.unlines
    [ "findMany ::",
      "  Pool Connection ->",
      "  " <> includeName incl <> " ->",
      "  (QueryBuilder " <> tableTypeName model <> " -> QueryBuilder " <> tableTypeName model <> ") ->",
      "  IO [" <> resultName <> "]",
      "findMany = Include.findMany @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindUnique :: Model -> ModelInclude -> Text
emitIncludeFindUnique model incl =
  T.unlines
    [ "findUnique :: Pool Connection -> " <> includeName incl <> " -> UUID -> IO (Maybe " <> resultName <> ")",
      "findUnique = Include.findUnique @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

emitIncludeFindUniqueOrError :: Model -> ModelInclude -> Text
emitIncludeFindUniqueOrError model incl =
  T.unlines
    [ "findUniqueOrError :: Pool Connection -> " <> includeName incl <> " -> UUID -> IO (Either ORMError " <> resultName <> ")",
      "findUniqueOrError = Include.findUniqueOrError @" <> tableTypeName model
    ]
  where
    resultName = includeResultName model incl

includeResultName :: Model -> ModelInclude -> Text
includeResultName model incl =
  resultTypeName stubSchema model (includeTree incl)
  where
    stubSchema = Schema {schemaEnums = [], schemaModels = [model], schemaIncludes = [incl]}

emitRecipeCreate :: Model -> ModelInclude -> Model -> Text
emitRecipeCreate root incl child =
  T.unlines
    [ "create ::",
      "  Pool Connection ->",
      "  " <> includeName incl <> " ->",
      "  CreateRecipeInput ->",
      "  IO (Either ORMError " <> includeResultName root incl <> ")",
      "create pool include input = do",
      "  recipeId <- V4.nextRandom",
      "  transaction pool $ \\conn -> do",
      "    recipeResult <-",
      "      Insert.insertConn @" <> tableTypeName root <> " @" <> rowTypeName root <> " conn (toRecipeCreate recipeId input)",
      "    case recipeResult of",
      "      Left err -> pure (Left err)",
      "      Right _ -> do",
      "        forM_ input.ingredients $ \\ingredient ->",
      "          Insert.executeInsertConn conn $",
      "            Insert.toInsertBuilder @" <> tableTypeName child <> " (toRecipeIngredientCreate recipeId ingredient)",
      "        Include.findUniqueOrErrorConn @" <> tableTypeName root <> " conn include recipeId"
    ]

emitRecipeUpdate :: Model -> ModelInclude -> Model -> Text -> Text
emitRecipeUpdate root incl child deleteField =
  T.unlines
    [ "update ::",
      "  Pool Connection ->",
      "  " <> includeName incl <> " ->",
      "  UUID ->",
      "  UpdateRecipeInput ->",
      "  IO (Either ORMError " <> includeResultName root incl <> ")",
      "update pool include recipeId input = do",
      "  now <- getCurrentTime",
      "  transaction pool $ \\conn -> do",
      "    updateResult <-",
      "      Update.updateConn @" <> tableTypeName root <> " @" <> rowTypeName root <> " conn recipeId (toRecipeUpdate now input)",
      "    case updateResult of",
      "      Left err -> pure (Left err)",
      "      Right _ -> do",
      "        case input.ingredients of",
      "          Nothing -> pure ()",
      "          Just ingredients -> do",
      "            _ <-",
      "              Delete.deleteConn conn $",
      "                Delete.whereDelete (fieldColumn " <> deleteField <> " <> \" = ?\") [toField recipeId] (Delete.emptyDelete @" <> tableTypeName child <> ")",
      "            forM_ (mapMaybe (toRecipeIngredientUpdate recipeId) ingredients) $ \\ri ->",
      "              Insert.executeInsertConn conn $",
      "                Insert.toInsertBuilder @" <> tableTypeName child <> " ri",
      "        Include.findUniqueOrErrorConn @" <> tableTypeName root <> " conn include recipeId"
    ]

emitRecipeDelete :: Model -> Text
emitRecipeDelete model =
  T.unlines
    [ "delete :: Pool Connection -> UUID -> IO ()",
      "delete pool recipeId = do",
      "  _ <- Ops.delete @" <> tableTypeName model <> " pool recipeId",
      "  pure ()"
    ]

emitToRecipeCreate :: Model -> Text
emitToRecipeCreate model =
  T.unlines
    [ "toRecipeCreate :: UUID -> CreateRecipeInput -> " <> createTypeName model,
      "toRecipeCreate recipeId input =",
      "  " <> createTypeName model,
      "    { id = Just recipeId,",
      "      createdAt = Nothing,",
      "      updatedAt = Nothing,",
      "      name = input.name,",
      "      description = Value input.description",
      "    }"
    ]

emitToRecipeUpdate :: Model -> Text
emitToRecipeUpdate model =
  T.unlines
    [ "toRecipeUpdate :: UTCTime -> UpdateRecipeInput -> " <> updateTypeName model,
      "toRecipeUpdate now input =",
      "  " <> updateTypeName model,
      "    { name = input.name,",
      "      createdAt = Nothing,",
      "      updatedAt = Just now,",
      "      description = maybe Omit Value input.description",
      "    }"
    ]

emitToRecipeIngredientCreate :: Model -> Text
emitToRecipeIngredientCreate model =
  T.unlines
    [ "toRecipeIngredientCreate :: UUID -> CreateRecipeIngredientInput -> " <> createTypeName model,
      "toRecipeIngredientCreate recipeId input =",
      "  " <> createTypeName model,
      "    { id = Nothing,",
      "      recipeId,",
      "      ingredientId = input.id,",
      "      amount = input.amount,",
      "      unit = input.unit",
      "    }"
    ]

emitToRecipeIngredientUpdate :: Model -> Text
emitToRecipeIngredientUpdate model =
  T.unlines
    [ "toRecipeIngredientUpdate :: UUID -> UpdateRecipeIngredientInput -> Maybe " <> createTypeName model,
      "toRecipeIngredientUpdate recipeId input = do",
      "  amount <- input.amount",
      "  unit <- input.unit",
      "  pure",
      "    " <> createTypeName model,
      "      { id = Nothing,",
      "        recipeId,",
      "        ingredientId = input.id,",
      "        amount,",
      "        unit",
      "      }"
    ]

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

hasManyChild :: Schema -> Model -> IncludeTree -> Model
hasManyChild schema parent edge =
  let rel = lookupRelation parent (includeRelation edge)
   in lookupModel schema (relToModel rel)

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

primaryKeyField :: Model -> FieldSpec
primaryKeyField model =
  case filter fieldIsPrimaryKey (modelFields model) of
    [f] -> f
    _ -> error "emit Client: model must have exactly one primary key"

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
