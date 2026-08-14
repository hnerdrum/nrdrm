{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Emit.Include
  ( emitIncludeADTs,
    emitResultADTs,
    emitIncludesJoin,
    emitShallowJoinBuilder,
    emitDeepJoinBuilder,
    emitBuildJoinChain,
    emitExecuteInclude,
    emitNestInclude,
    emitShallowNestHelpers,
    emitDeepNestHelpers,
    emitIncludeModule,
  )
where

import Data.Char (toLower, toUpper)
import Data.List (find)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.Emit.FlatRow
  ( DeepJoin (..),
    ShallowJoin (..),
    childJoinAlias,
    deepColumnListName,
    deepJoin,
    deepJoinRowName,
    emitDeepColumnList,
    emitDeepFlatJoinRow,
    emitShallowColumnList,
    emitShallowFlatJoinRow,
    grandJoinAlias,
    rootJoinAlias,
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

emitShallowNestHelpers :: Schema -> ModelInclude -> Text
emitShallowNestHelpers schema incl =
  T.intercalate "\n" $
    filter
      (not . T.null)
      [ emitNestRowsFn schema incl,
        emitFromGroupFn schema incl,
        emitEmptyChildWrap schema incl,
        emitToRootRow schema incl,
        emitToChildRow schema incl
      ]

emitDeepNestHelpers :: Schema -> ModelInclude -> Text
emitDeepNestHelpers schema incl =
  T.intercalate
    "\n"
    [ emitDeepNestRowsFn schema incl,
      emitDeepRootFromGroupFn schema incl,
      emitDeepChildFromGroupFn schema incl,
      emitToRootRowFromDeep schema incl,
      emitToChildRowFromDeep schema incl,
      emitToGrandRow schema incl
    ]

nestRowsName :: Model -> Text
nestRowsName root = "nest" <> modelName root <> "Rows"

deepNestRowsName :: Model -> Model -> Model -> Text
deepNestRowsName root child grand =
  "nest" <> modelName root <> modelName child <> modelName grand <> "Rows"

deepRootFromGroupName :: Schema -> Model -> Model -> [IncludeTree] -> Text
deepRootFromGroupName _schema root child nestedKids =
  lowerFirst (modelName root)
    <> "With"
    <> T.concat
      [ upperFirst (includeFieldName child (lookupRelation child (includeRelation e)))
        | e <- nestedKids
      ]
    <> "From"
    <> modelName root
    <> "Group"

emitDeepNestRowsFn :: Schema -> ModelInclude -> Text
emitDeepNestRowsFn schema incl =
  T.unlines
    [ nestFn <> " :: [" <> flatRow <> "] -> [" <> resultName <> "]",
      nestFn <> " =",
      "  map " <> groupFn <> " . groupByKey (." <> rootPkBinder <> ")"
    ]
  where
    DeepJoin {djRoot, djChild, djGrand} = deepJoin schema incl
    flatRow = deepJoinRowName djRoot djChild djGrand
    resultName = resultTypeName schema djRoot (includeTree incl)
    nestFn = deepNestRowsName djRoot djChild djGrand
    nestedKids = includeChildren (head (includeTree incl))
    groupFn = deepRootFromGroupName schema djRoot djChild nestedKids
    rootPkBinder = fieldBinder djRoot (primaryKeyField djRoot)

emitDeepRootFromGroupFn :: Schema -> ModelInclude -> Text
emitDeepRootFromGroupFn schema incl =
  T.unlines
    [ groupFn <> " :: [" <> flatRow <> "] -> " <> resultName,
      groupFn <> " rows@(firstRow : _) =",
      "  " <> resultName,
      "    { " <> rootVar <> " = " <> toRootDeepFn <> " firstRow,",
      "      " <> childField <> " = mapMaybe " <> childGroupFn <> " $ groupByKey (." <> childPkBinder <> ") rows",
      "    }",
      groupFn <> " [] =",
      "  error \"" <> groupFn <> ": empty group\""
    ]
  where
    DeepJoin {djRoot, djChild, djGrand, djChildRel} = deepJoin schema incl
    flatRow = deepJoinRowName djRoot djChild djGrand
    resultName = resultTypeName schema djRoot (includeTree incl)
    nestedKids = includeChildren (head (includeTree incl))
    groupFn = deepRootFromGroupName schema djRoot djChild nestedKids
    rootVar = lowerFirst (modelName djRoot)
    toRootDeepFn = toRowFn djRoot <> "From" <> modelName djGrand
    childField = includeFieldName djRoot djChildRel
    childGroupFn = fromGroupName schema djChild nestedKids
    childPkBinder = fieldBinder djChild (childGroupKeyField djChild djChildRel)

emitDeepChildFromGroupFn :: Schema -> ModelInclude -> Text
emitDeepChildFromGroupFn schema incl =
  T.unlines
    [ groupFn <> " :: [" <> flatRow <> "] -> Maybe " <> childResult,
      groupFn <> " rows@(firstRow : _)",
      "  | Just _ <- firstRow." <> childPkBinder <> " =",
      "      Just",
      "        " <> childResult,
      "          { " <> childVar <> " = " <> toChildDeepFn <> " firstRow,",
      "            " <> grandField <> " = " <> grandExpr,
      "          }",
      "  | otherwise = Nothing",
      groupFn <> " [] = Nothing"
    ]
  where
    DeepJoin {djRoot, djChild, djGrand, djChildRel, djGrandRel} = deepJoin schema incl
    flatRow = deepJoinRowName djRoot djChild djGrand
    nestedKids = includeChildren (head (includeTree incl))
    childResult = resultTypeName schema djChild nestedKids
    groupFn = fromGroupName schema djChild nestedKids
    childVar = lowerFirst (modelName djChild)
    childPkBinder = fieldBinder djChild (childGroupKeyField djChild djChildRel)
    toChildDeepFn = toRowFn djChild <> "From" <> modelName djGrand
    grandField = includeFieldName djChild djGrandRel
    toGrandFn = toRowFn djGrand
    grandExpr = case relKind djGrandRel of
      RelBelongsTo -> toGrandFn <> " firstRow"
      RelHasMany -> "mapMaybe " <> toGrandFn <> " rows"

emitToRootRowFromDeep :: Schema -> ModelInclude -> Text
emitToRootRowFromDeep schema incl =
  T.unlines
    [ toFn <> " :: " <> flatRow <> " -> " <> rootRow,
      toFn <> " row = " <> rootRow <> " {" <> T.intercalate ", " assigns <> "}"
    ]
  where
    DeepJoin {djRoot, djChild, djGrand, djRootFields} = deepJoin schema incl
    flatRow = deepJoinRowName djRoot djChild djGrand
    rootRow = modelName djRoot <> "Row"
    toFn = toRowFn djRoot <> "From" <> modelName djGrand
    assigns =
      [ fieldName f <> " = row." <> fieldBinder djRoot f
        | f <- djRootFields
      ]

emitToChildRowFromDeep :: Schema -> ModelInclude -> Text
emitToChildRowFromDeep schema incl =
  T.unlines
    [ toFn <> " :: " <> flatRow <> " -> " <> childRow,
      toFn <> " row =",
      "  " <> childRow,
      "    { " <> T.intercalate ",\n      " assigns,
      "    }"
    ]
  where
    DeepJoin {djRoot, djChild, djGrand, djChildRel, djChildFields} = deepJoin schema incl
    flatRow = deepJoinRowName djRoot djChild djGrand
    childRow = modelName djChild <> "Row"
    toFn = toRowFn djChild <> "From" <> modelName djGrand
    fkField =
      case find ((== relForeignField djChildRel) . fieldName) (modelFields djChild) of
        Just f -> f
        Nothing -> error "emitToChildRowFromDeep: missing FK on child"
    localRootField =
      case find ((== relLocalField djChildRel) . fieldName) (modelFields djRoot) of
        Just f -> f
        Nothing -> error "emitToChildRowFromDeep: missing local on root"
    assigns =
      [ fieldName f
          <> " = fromMaybe (error \""
          <> toFn
          <> ": missing "
          <> fieldName f
          <> "\") row."
          <> fieldBinder djChild f
        | f <- djChildFields
      ]
        ++ [fieldName fkField <> " = row." <> fieldBinder djRoot localRootField]

emitToGrandRow :: Schema -> ModelInclude -> Text
emitToGrandRow schema incl =
  T.unlines
    [ toFn <> " :: " <> flatRow <> " -> Maybe " <> grandRow,
      toFn <> " row",
      "  | " <> T.intercalate ",\n    " justBinds <> " =",
      "      Just " <> grandRow <> " {" <> T.intercalate ", " assigns <> "}",
      "  | otherwise = Nothing"
    ]
  where
    DeepJoin {djRoot, djChild, djGrand, djGrandRel, djGrandFields} = deepJoin schema incl
    flatRow = deepJoinRowName djRoot djChild djGrand
    grandRow = modelName djGrand <> "Row"
    toFn = toRowFn djGrand
    (justBinds, assigns) = case relKind djGrandRel of
      RelBelongsTo ->
        ( [ "Just " <> patVar djGrand f <> " <- row." <> fieldBinder djGrand f
            | f <- djGrandFields
          ],
          [ fieldName f <> " = " <> patVar djGrand f
            | f <- djGrandFields
          ]
        )
      RelHasMany ->
        ( grandJustBinds ++ childPkBind,
          grandAssigns ++ [fieldName grandFkField <> " = " <> patVar djChild childPkField]
        )
    childPkField = primaryKeyField djChild
    grandFkField =
      case find ((== relForeignField djGrandRel) . fieldName) (modelFields djGrand) of
        Just f -> f
        Nothing -> error "emitToGrandRow: missing FK on grand"
    grandJustBinds =
      [ "Just " <> patVar djGrand f <> " <- row." <> fieldBinder djGrand f
        | f <- djGrandFields
      ]
    childPkBind =
      [ "Just " <> patVar djChild childPkField <> " <- row." <> fieldBinder djChild childPkField
      ]
    grandAssigns =
      [ fieldName f <> " = " <> patVar djGrand f
        | f <- djGrandFields
      ]

fromGroupName :: Schema -> Model -> [IncludeTree] -> Text
fromGroupName schema root edges =
  lowerFirst (resultTypeName schema root edges) <> "FromGroup"

emitNestRowsFn :: Schema -> ModelInclude -> Text
emitNestRowsFn schema incl =
  T.unlines
    [ nestFn <> " :: [" <> flatRow <> "] -> [" <> resultName <> "]",
      nestFn <> " =",
      "  map " <> groupFn <> " . groupByKey (." <> rootPkBinder <> ")"
    ]
  where
    ShallowJoin {sjRoot, sjChild} = shallowJoin schema incl
    flatRow = shallowJoinRowName sjRoot sjChild
    resultName = resultTypeName schema sjRoot (includeTree incl)
    nestFn = nestRowsName sjRoot
    groupFn = fromGroupName schema sjRoot (includeTree incl)
    rootPkBinder = fieldBinder sjRoot (primaryKeyField sjRoot)

emitFromGroupFn :: Schema -> ModelInclude -> Text
emitFromGroupFn schema incl =
  T.unlines
    [ groupFn <> " :: [" <> flatRow <> "] -> " <> resultName,
      groupFn <> " rows@(firstRow : _) =",
      "  " <> resultName,
      "    { " <> rootVar <> " = " <> toRootFn <> " firstRow,",
      "      " <> childField <> " = " <> childExpr,
      "    }",
      groupFn <> " [] =",
      "  error \"" <> groupFn <> ": empty group\""
    ]
  where
    ShallowJoin {sjRoot, sjChild, sjRel} = shallowJoin schema incl
    flatRow = shallowJoinRowName sjRoot sjChild
    resultName = resultTypeName schema sjRoot (includeTree incl)
    groupFn = fromGroupName schema sjRoot (includeTree incl)
    rootVar = lowerFirst (modelName sjRoot)
    toRootFn = toRowFn sjRoot
    edge = head (includeTree incl)
    childField = includeFieldName sjRoot sjRel
    childHasNested = not (null (includeChildren edge))
    toChildFn = toRowFn sjChild
    childExpr
      | childHasNested =
          "map " <> emptyWrapFn sjChild (includeChildren edge) <> " $ mapMaybe " <> toChildFn <> " rows"
      | otherwise =
          "mapMaybe " <> toChildFn <> " rows"

emptyWrapFn :: Model -> [IncludeTree] -> Text
emptyWrapFn child kids =
  lowerFirst (modelName child)
    <> "WithNo"
    <> T.concat (map (upperFirst . includeFieldNameFromEdge child) kids)
  where
    includeFieldNameFromEdge parent edge =
      -- relation name only; strip parent prefix like includeFieldName
      case T.stripPrefix (lowerFirst (modelName parent)) (includeRelation edge) of
        Just rest | not (T.null rest) -> lowerFirst rest
        _ -> lowerFirst (includeRelation edge)

emitEmptyChildWrap :: Schema -> ModelInclude -> Text
emitEmptyChildWrap schema incl =
  case includeTree incl of
    (edge : _)
      | not (null (includeChildren edge)) ->
          let ShallowJoin {sjChild} = shallowJoin schema incl
              kids = includeChildren edge
              wrapFn = emptyWrapFn sjChild kids
              childResult = resultTypeName schema sjChild kids
              childVar = lowerFirst (modelName sjChild)
              emptyKids =
                T.intercalate ", " $
                  map (emptyNestedField schema sjChild) kids
           in T.unlines
                [ wrapFn <> " :: " <> modelName sjChild <> "Row -> " <> childResult,
                  wrapFn <> " " <> childVar <> " = " <> childResult <> " {" <> childVar <> ", " <> emptyKids <> "}"
                ]
    _ -> ""

emptyNestedField :: Schema -> Model -> IncludeTree -> Text
emptyNestedField _schema parent edge =
  name <> " = " <> emptyVal
  where
    rel = lookupRelation parent (includeRelation edge)
    name = includeFieldName parent rel
    emptyVal = case relKind rel of
      RelHasMany -> "[]"
      RelBelongsTo -> "Nothing"

emitToRootRow :: Schema -> ModelInclude -> Text
emitToRootRow schema incl =
  T.unlines
    [ toFn <> " :: " <> flatRow <> " -> " <> rootRow,
      toFn <> " row = " <> rootRow <> " {" <> T.intercalate ", " assigns <> "}"
    ]
  where
    ShallowJoin {sjRoot, sjChild, sjRootFields} = shallowJoin schema incl
    flatRow = shallowJoinRowName sjRoot sjChild
    rootRow = modelName sjRoot <> "Row"
    toFn = toRowFn sjRoot
    assigns =
      [ fieldName f <> " = row." <> fieldBinder sjRoot f
        | f <- sjRootFields
      ]

emitToChildRow :: Schema -> ModelInclude -> Text
emitToChildRow schema incl =
  T.unlines
    [ toFn <> " :: " <> flatRow <> " -> Maybe " <> childRow,
      toFn <> " row",
      "  | " <> T.intercalate ",\n    " justBinds <> " =",
      "      Just " <> childRow <> " {" <> T.intercalate ", " assigns <> "}",
      "  | otherwise = Nothing"
    ]
  where
    ShallowJoin {sjRoot, sjChild, sjRel, sjChildFields} = shallowJoin schema incl
    flatRow = shallowJoinRowName sjRoot sjChild
    childRow = modelName sjChild <> "Row"
    toFn = toRowFn sjChild
    justBinds =
      [ "Just " <> patVar sjChild f <> " <- row." <> fieldBinder sjChild f
        | f <- sjChildFields
      ]
    fkField =
      case find ((== relForeignField sjRel) . fieldName) (modelFields sjChild) of
        Just f -> f
        Nothing -> error "emitToChildRow: missing FK field on child"
    localRootField =
      case find ((== relLocalField sjRel) . fieldName) (modelFields sjRoot) of
        Just f -> f
        Nothing -> error "emitToChildRow: missing local field on root"
    assigns =
      [ fieldName f <> " = " <> patVar sjChild f
        | f <- sjChildFields
      ]
        ++ [fieldName fkField <> " = row." <> fieldBinder sjRoot localRootField]

patVar :: Model -> FieldSpec -> Text
patVar model f
  | fieldName f == "id" =
      T.toLower (T.take 1 (modelName model)) <> "id"
  | otherwise = fieldName f

toRowFn :: Model -> Text
toRowFn model = "to" <> modelName model <> "Row"

fieldBinder :: Model -> FieldSpec -> Text
fieldBinder model f =
  lowerFirst (modelName model) <> upperFirst (fieldName f)

primaryKeyField :: Model -> FieldSpec
primaryKeyField model =
  case filter fieldIsPrimaryKey (modelFields model) of
    [f] -> f
    _ -> error "emit Include: model must have exactly one primary key"

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
            <> rootJoinAlias sjRoot
            <> "\" \""
            <> childJoinAlias sjRoot sjChild
            <> "\""
        ]
  where
    ShallowJoin {sjRoot, sjChild, sjRel} = shallowJoin schema incl
    builderName = shallowJoinBuilderName sjRoot sjChild
    rootTable = modelName sjRoot <> "Table"
    colsName = shallowColumnListName sjRoot sjChild

emitDeepJoinBuilder :: Schema -> ModelInclude -> Text
emitDeepJoinBuilder schema incl =
  case relKind djGrandRel of
    RelBelongsTo ->
      T.unlines
        [ builderName <> " :: JoinChain.JoinChain " <> rootTable,
          builderName <> " =",
          "  JoinChain.selectColumns " <> colsName <> " $",
          "    JoinChain.addBelongsToJoin "
            <> relName djGrandRel
            <> " \""
            <> childJoinAlias djRoot djChild
            <> "\" \""
            <> grandJoinAlias djRoot djChild djGrand
            <> "\" "
            <> shallowBuilder
        ]
    RelHasMany ->
      T.unlines
        [ builderName <> " :: JoinChain.JoinChain " <> rootTable,
          builderName <> " =",
          "  JoinChain.selectColumns " <> colsName <> " $",
          "    JoinChain.addHasManyJoin "
            <> relName djGrandRel
            <> " \""
            <> childJoinAlias djRoot djChild
            <> "\" \""
            <> grandJoinAlias djRoot djChild djGrand
            <> "\" "
            <> shallowBuilder
        ]
  where
    DeepJoin {djRoot, djChild, djGrand, djGrandRel} = deepJoin schema incl
    builderName = deepJoinBuilderName djRoot djChild djGrand
    shallowBuilder = shallowJoinBuilderName djRoot djChild
    rootTable = modelName djRoot <> "Table"
    colsName = deepColumnListName djRoot djChild djGrand

emitBuildJoinChain :: Schema -> ModelInclude -> Text
emitBuildJoinChain schema incl =
  T.unlines $
    [ "instance BuildJoinChain " <> rootTable <> " " <> inclName <> " where",
      "  type JoinFlatRow " <> inclName <> " = " <> shallowRow
    ]
      ++ buildJoinChainArms schema incl
  where
    ShallowJoin {sjRoot, sjChild} = shallowJoin schema incl
    rootTable = modelName sjRoot <> "Table"
    inclName = includeName incl
    shallowRow = shallowJoinRowName sjRoot sjChild

buildJoinChainArms :: Schema -> ModelInclude -> [Text]
buildJoinChainArms schema incl =
  case includeTree incl of
    (edge : _)
      | let kids = includeChildren edge,
        not (null kids) ->
          let ShallowJoin {sjRoot, sjChild, sjRel} = shallowJoin schema incl
              DeepJoin {djRoot, djChild, djGrand} = deepJoin schema incl
              inclName = includeName incl
              rootField = includeFieldName sjRoot sjRel
              nestedType = modelName sjChild <> "Include"
              boolRel = lookupRelation sjChild (includeRelation (head kids))
              boolField = includeFieldName sjChild boolRel
              shallowBuilder = shallowJoinBuilderName sjRoot sjChild
              deepBuilder = deepJoinBuilderName djRoot djChild djGrand
           in [ "  buildJoinChain " <> inclName <> " {" <> rootField <> " = Just " <> nestedType <> " {" <> boolField <> " = False}} =",
                "    " <> shallowBuilder,
                "  buildJoinChain " <> inclName <> " {" <> rootField <> " = Just " <> nestedType <> " {" <> boolField <> " = True}} =",
                "    " <> deepBuilder,
                "  buildJoinChain " <> inclName <> " {" <> rootField <> " = Nothing} =",
                "    " <> shallowBuilder
              ]
    _ ->
      let ShallowJoin {sjRoot, sjChild} = shallowJoin schema incl
       in ["  buildJoinChain _ = " <> shallowJoinBuilderName sjRoot sjChild]

emitExecuteInclude :: Schema -> ModelInclude -> Text
emitExecuteInclude schema incl =
  T.unlines
    [ "instance {-# OVERLAPPING #-} ExecuteInclude " <> rootTable <> " " <> inclName <> " " <> resultName <> " where",
      "  executeInclude conn include modifier =",
      "    case include." <> rootField <> " of",
      "      Nothing -> do",
      "        roots <- findManyConn @" <> rootTable <> " @" <> rootRow <> " conn modifier",
      "        pure $ map (wrapRoot include) roots",
      "      Just " <> nestedType <> " {" <> boolField <> " = False} -> do",
      "        let chain = applyRootFilter " <> shallowBuilder <> " modifier",
      "        flatRows <- JoinChain.runJoinChainConn @" <> shallowRow <> " conn chain",
      "        pure $ " <> shallowNest <> " flatRows",
      "      Just " <> nestedType <> " {" <> boolField <> " = True} -> do",
      "        let chain = applyRootFilter " <> deepBuilder <> " modifier",
      "        flatRows <- JoinChain.runJoinChainConn @" <> deepRow <> " conn chain",
      "        pure $ " <> deepNest <> " flatRows"
    ]
  where
    ShallowJoin {sjRoot, sjChild, sjRel} = shallowJoin schema incl
    DeepJoin {djRoot, djChild, djGrand} = deepJoin schema incl
    rootTable = modelName sjRoot <> "Table"
    inclName = includeName incl
    resultName = resultTypeName schema sjRoot (includeTree incl)
    rootRow = modelName sjRoot <> "Row"
    rootField = includeFieldName sjRoot sjRel
    edge = head (includeTree incl)
    kids = includeChildren edge
    nestedType = modelName sjChild <> "Include"
    boolRel = lookupRelation sjChild (includeRelation (head kids))
    boolField = includeFieldName sjChild boolRel
    shallowBuilder = shallowJoinBuilderName sjRoot sjChild
    deepBuilder = deepJoinBuilderName djRoot djChild djGrand
    shallowRow = shallowJoinRowName sjRoot sjChild
    deepRow = deepJoinRowName djRoot djChild djGrand
    shallowNest = nestRowsName sjRoot
    deepNest = deepNestRowsName djRoot djChild djGrand

shallowJoinBuilderName :: Model -> Model -> Text
shallowJoinBuilderName root child =
  "build" <> modelName root <> modelName child <> "Join"

deepJoinBuilderName :: Model -> Model -> Model -> Text
deepJoinBuilderName root child grand =
  "build" <> modelName root <> modelName child <> modelName grand <> "Join"

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
          emitIncludesJoin schema incl,
          emitShallowFlatJoinRow schema incl,
          emitShallowColumnList schema incl,
          emitShallowJoinBuilder schema incl
        ],
        deepPieces,
        [ emitBuildJoinChain schema incl,
          emitNestInclude schema incl,
          emitShallowNestHelpers schema incl
        ],
        deepNest,
        [emitExecuteInclude schema incl | hasDeepNest incl]
      ]
  where
    deepPieces
      | hasDeepNest incl =
          [ emitDeepFlatJoinRow schema incl,
            emitDeepColumnList schema incl,
            emitDeepJoinBuilder schema incl
          ]
      | otherwise = []
    deepNest
      | hasDeepNest incl = [emitDeepNestHelpers schema incl]
      | otherwise = []

hasDeepNest :: ModelInclude -> Bool
hasDeepNest incl =
  case includeTree incl of
    (edge : _) -> not (null (includeChildren edge))
    _ -> False

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
    ShallowJoin {sjRoot, sjChild} = shallowJoin schema incl
    edge = case includeTree incl of
      (e : _) -> e
      [] -> error "emitIncludeExports: empty include tree"
    nestedExport =
      [ modelName sjChild <> "Include (..)"
        | not (null (includeChildren edge))
      ]
    resultExports =
      [ itdName d <> " (..)"
        | d <- collectResultTypes schema incl
      ]
    flatExports =
      shallowJoinRowName sjRoot sjChild <> " (..)"
        : [ deepJoinRowName djRoot djChild djGrand <> " (..)"
            | hasDeepNest incl,
              let DeepJoin {djRoot, djChild, djGrand} = deepJoin schema incl
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
        rootImport,
        childImport,
        grandImport,
        "import qualified " <> rootMod <> " as " <> modelName sjRoot,
        "import qualified " <> childMod <> " as " <> modelName sjChild,
        grandQualified
      ]
      ++ enumImports schema incl
  where
    ShallowJoin {sjRoot, sjChild, sjRel, sjRootFields, sjChildFields} =
      shallowJoin schema incl
    rootMod = schemaModulePrefix moduleName <> modelName sjRoot
    childMod = schemaModulePrefix moduleName <> modelName sjChild
    deep = hasDeepNest incl
    dj =
      if deep
        then deepJoin schema incl
        else
          DeepJoin
            { djRoot = sjRoot,
              djChild = sjChild,
              djGrand = sjChild,
              djChildRel = sjRel,
              djGrandRel = sjRel,
              djRootFields = [],
              djChildFields = [],
              djGrandFields = []
            }
    DeepJoin {djGrand, djGrandRel, djGrandFields, djChildFields = deepChildFields} = dj
    allFields =
      sjRootFields
        ++ sjChildFields
        ++ [f | deep, f <- deepChildFields ++ djGrandFields]
    needsText = any ((== TyText) . fieldType) allFields
    needsUuid = any ((== TyUuid) . fieldType) allFields
    needsTime = any ((== TyTimestamptz) . fieldType) allFields
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
    childImport =
      "import "
        <> childMod
        <> " ("
        <> T.intercalate
          ", "
          ( modelName sjChild <> "Row (..)"
              : [relName djGrandRel | deep]
          )
        <> ")"
    grandImport =
      if deep && modelName djGrand /= modelName sjChild
        then
          "import "
            <> schemaModulePrefix moduleName
            <> modelName djGrand
            <> " ("
            <> modelName djGrand
            <> "Row (..))"
        else ""
    grandQualified =
      if deep && modelName djGrand /= modelName sjChild
        then
          "import qualified "
            <> schemaModulePrefix moduleName
            <> modelName djGrand
            <> " as "
            <> modelName djGrand
        else ""

schemaModulePrefix :: Text -> Text
schemaModulePrefix moduleName =
  case T.breakOnEnd "." moduleName of
    (prefix, _) | not (T.null prefix) -> prefix
    _ -> ""

enumImports :: Schema -> ModelInclude -> [Text]
enumImports schema incl =
  [ "import " <> imp <> " (" <> enumName e <> ")"
    | e <- schemaEnums schema,
      enumName e `elem` usedEnumNames schema incl,
      Just imp <- [enumImport e]
  ]

usedEnumNames :: Schema -> ModelInclude -> [Text]
usedEnumNames schema incl =
  [ name
    | f <- includeFields schema incl,
      TyEnum name <- [fieldType f]
  ]

includeFields :: Schema -> ModelInclude -> [FieldSpec]
includeFields schema incl =
  let ShallowJoin {sjRootFields, sjChildFields} = shallowJoin schema incl
   in if hasDeepNest incl
        then
          let DeepJoin {djGrandFields, djChildFields = deepChildFields} = deepJoin schema incl
           in sjRootFields ++ sjChildFields ++ deepChildFields ++ djGrandFields
        else sjRootFields ++ sjChildFields

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

childGroupKeyField :: Model -> RelationSpec -> FieldSpec
childGroupKeyField child childRel =
  let childPk = primaryKeyField child
   in if fieldName childPk == relForeignField childRel
        then fromMaybe childPk $
          find ((/= fieldName childPk) . fieldName) (modelFields child)
        else childPk

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