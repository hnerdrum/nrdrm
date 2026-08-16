{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.IncludePath
  ( defaultMaxIncludeDepth,
    PathStep (..),
    JoinPath (..),
    joinPathModels,
    joinPathSteps,
    joinPathTake,
    includeMaxDepth,
    includeLongestJoinPath,
    includePresetJoinPaths,
    joinRowName,
    joinRowNameFromModels,
    columnListName,
    joinBuilderName,
    lookupModelAlias,
    assignIncludeModelAliases,
  )
where

import Data.Bifunctor (first)
import Data.Char (toLower)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.IR
import ORM.Codegen.JoinAlias (assignModelAliases)

defaultMaxIncludeDepth :: Int
defaultMaxIncludeDepth = 5

data PathStep = PathStep
  { psFrom :: Model,
    psRel :: RelationSpec,
    psTo :: Model
  }
  deriving (Show)

newtype JoinPath = JoinPath
  { jpSteps :: [PathStep]
  }
  deriving (Show)

joinPathModels :: JoinPath -> [Model]
joinPathModels JoinPath {jpSteps = steps} =
  case steps of
    [] -> []
    (PathStep {psFrom = root} : _) ->
      root : map psTo steps

joinPathSteps :: JoinPath -> [PathStep]
joinPathSteps = jpSteps

joinPathTake :: Int -> JoinPath -> JoinPath
joinPathTake n JoinPath {jpSteps = steps} =
  JoinPath {jpSteps = take n steps}

includeMaxDepth :: Schema -> ModelInclude -> Int
includeMaxDepth schema incl =
  length (joinPathModels (includeLongestJoinPath schema incl))

includeLongestJoinPath :: Schema -> ModelInclude -> JoinPath
includeLongestJoinPath schema incl =
  case includeTree incl of
    [] ->
      error $
        "includeLongestJoinPath: include "
          <> T.unpack (includeName incl)
          <> " has empty tree"
    edges ->
      let root = lookupModel schema (includeRootModel incl)
       in JoinPath {jpSteps = longestPathSteps schema root edges}

includePresetJoinPaths :: Schema -> ModelInclude -> [JoinPath]
includePresetJoinPaths schema incl =
  let full = includeLongestJoinPath schema incl
      maxSteps = length (jpSteps full)
   in [joinPathTake n full | n <- [1 .. maxSteps]]

longestPathSteps :: Schema -> Model -> [IncludeTree] -> [PathStep]
longestPathSteps schema fromModel edges =
  case edges of
    [] -> []
    (edge : _) ->
      let rel = lookupRelation fromModel (includeRelation edge)
          toModel = lookupModel schema (relToModel rel)
          step = PathStep {psFrom = fromModel, psRel = rel, psTo = toModel}
          deeper =
            case includeChildren edge of
              [] -> []
              childEdges -> longestPathSteps schema toModel childEdges
       in step : deeper

joinRowNameFromModels :: [Model] -> Text
joinRowNameFromModels models =
  T.concat (map modelName models) <> "JoinRow"

joinRowName :: JoinPath -> Text
joinRowName = joinRowNameFromModels . joinPathModels

columnListName :: JoinPath -> Text
columnListName path =
  case joinPathModels path of
    [] -> error "columnListName: empty join path"
    (root : rest) ->
      lowerFirst (modelName root) <> T.concat (map modelName rest) <> "Columns"

joinBuilderName :: JoinPath -> Text
joinBuilderName path =
  "build" <> T.concat (map modelName (joinPathModels path)) <> "Join"

assignIncludeModelAliases :: Schema -> ModelInclude -> [(Text, Text)]
assignIncludeModelAliases schema incl =
  map (first modelName) $
    assignModelAliases (joinPathModels (includeLongestJoinPath schema incl))

lookupModelAlias :: [(Text, Text)] -> Model -> Text
lookupModelAlias aliases model =
  case lookup (modelName model) aliases of
    Just alias -> alias
    Nothing ->
      error $
        "lookupModelAlias: no alias for model "
          <> T.unpack (modelName model)

lookupModel :: Schema -> Text -> Model
lookupModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just m -> m
    Nothing -> error $ "IncludePath: unknown model " <> T.unpack name

lookupRelation :: Model -> Text -> RelationSpec
lookupRelation model name =
  case find ((== name) . relName) (modelRelations model) of
    Just r -> r
    Nothing ->
      error $
        "IncludePath: unknown relation "
          <> T.unpack name
          <> " on "
          <> T.unpack (modelName model)

lowerFirst :: Text -> Text
lowerFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toLower c) rest
