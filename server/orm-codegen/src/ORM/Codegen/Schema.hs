module ORM.Codegen.Schema
  ( Schema (..),
    schema,
    Model (..),
    model,
    table,
    FieldSpec (..),
    FieldType (..),
    FieldDefault (..),
    uuid,
    text,
    int,
    bool,
    timestamptz,
    enumField,
    pk,
    nullable,
    updatedAt,
    withDefault,
    column,
    (&),
    RelationSpec (..),
    RelationKind (..),
    JoinKind (..),
    hasMany,
    belongsTo,
    ModelInclude (..),
    IncludeTree (..),
    IncludeDecl (..),
    includeGraph,
    include,
    tree,
    EnumSpec (..),
    EnumVariant (..),
    enum_,
    enumImportFrom,
    variant,
    variantMap,
    UniqueConstraint (..),
    unique_,
    isFullGraphInclude,
  )
where

import Data.Function ((&))
import Data.List (find)
import Data.Text (Text)
import ORM.Codegen.IR
  ( EnumSpec (..),
    EnumVariant (..),
    FieldDefault (..),
    FieldSpec (..),
    FieldType (..),
    IncludeTree (..),
    JoinKind (..),
    Model (..),
    ModelInclude (..),
    RelationKind (..),
    RelationSpec (..),
    Schema (..),
    UniqueConstraint (..),
    enumImportFrom,
    enum_,
    nullable,
    pk,
    unique_,
    updatedAt,
    variant,
    variantMap,
    withDefault,
  )
import qualified ORM.Codegen.IR as IR
import ORM.Codegen.TextUtil (camelToSnake)

schema :: [EnumSpec] -> [Model] -> [IncludeDecl] -> [UniqueConstraint] -> Schema
schema enums models includes uniques =
  let declared = map (resolveInclude models) includes
      declaredRoots = map includeRootModel declared
      auto =
        [ resolveInclude models (IncludeGraph (fullGraphIncludeName (modelName m)) (modelName m))
          | m <- models,
            not (null (modelRelations m)),
            modelName m `notElem` declaredRoots
        ]
   in Schema
        { schemaEnums = enums,
          schemaModels = models,
          schemaIncludes = declared ++ auto,
          schemaUniques = uniques
        }

model :: Text -> [FieldSpec] -> [RelationSpec] -> Model
model name fields rels =
  Model
    { modelName = name,
      modelTable = camelToSnake name,
      modelFields = fields,
      modelRelations = map bind rels
    }
  where
    bind rel = rel {relFromModel = name}

table :: Text -> Model -> Model
table name m = m {modelTable = name}

uuid :: Text -> FieldSpec
uuid = typedField IR.TyUuid

text :: Text -> FieldSpec
text = typedField IR.TyText

int :: Text -> FieldSpec
int = typedField IR.TyInt

bool :: Text -> FieldSpec
bool = typedField IR.TyBool

timestamptz :: Text -> FieldSpec
timestamptz = typedField IR.TyTimestamptz

enumField :: Text -> Text -> FieldSpec
enumField name enumName = typedField (IR.TyEnum enumName) name

typedField :: IR.FieldType -> Text -> FieldSpec
typedField ty name =
  IR.field name ty & column (camelToSnake name)

column :: Text -> FieldSpec -> FieldSpec
column = IR.column

hasMany ::
  Text ->
  Text ->
  Text ->
  RelationSpec
hasMany name toModel = IR.hasMany name "" toModel "id"

belongsTo :: Text -> Text -> Text -> RelationSpec
belongsTo name toModel foreignFld = IR.belongsTo name "" toModel foreignFld "id"

data IncludeDecl
  = IncludeGraph Text Text
  | IncludeExplicit Text Text [IncludeTree]
  deriving (Show, Eq)

includeGraph :: Text -> Text -> IncludeDecl
includeGraph = IncludeGraph

include :: Text -> Text -> [IncludeTree] -> IncludeDecl
include = IncludeExplicit

tree :: Text -> [IncludeTree] -> IncludeTree
tree = IncludeTree

resolveInclude :: [Model] -> IncludeDecl -> ModelInclude
resolveInclude models (IncludeGraph name root) =
  ModelInclude
    { includeName = name,
      includeRootModel = root,
      includeTree = graphTree models root
    }
resolveInclude _ (IncludeExplicit name root edges) =
  ModelInclude
    { includeName = name,
      includeRootModel = root,
      includeTree = edges
    }

graphTree :: [Model] -> Text -> [IncludeTree]
graphTree models rootName =
  case findModel models rootName of
    Nothing -> []
    Just root -> walk [] root
  where
    walk path current =
      map (edge path current) (modelRelations current)
    edge path current rel =
      let childName = relToModel rel
          nextPath = modelName current : path
       in IncludeTree
            { includeRelation = relName rel,
              includeChildren =
                if childName `elem` nextPath
                  then []
                  else case findModel models childName of
                    Nothing -> []
                    Just child -> walk nextPath child
            }

isFullGraphInclude :: [Model] -> ModelInclude -> Bool
isFullGraphInclude models incl =
  includeName incl == fullGraphIncludeName (includeRootModel incl)
    && includeTree incl == graphTree models (includeRootModel incl)

fullGraphIncludeName :: Text -> Text
fullGraphIncludeName root = root <> "Include"

findModel :: [Model] -> Text -> Maybe Model
findModel models name =
  find ((== name) . modelName) models
