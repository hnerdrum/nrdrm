{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.JoinAlias
  ( IncludeAliases (..),
    assignIncludeAliases,
    includeModelsInOrder,
    assignModelAliases,
    allocateJoinAlias,
    aliasCandidates,
  )
where

import Data.Char (isUpper, toLower)
import Data.List (find, nub)
import Data.Text (Text)
import qualified Data.Text as T
import ORM.Codegen.IR

data IncludeAliases = IncludeAliases
  { iaRoot :: Text,
    iaChild :: Text,
    iaGrand :: Maybe Text
  }
  deriving (Show, Eq)

assignIncludeAliases :: Schema -> ModelInclude -> IncludeAliases
assignIncludeAliases schema incl =
  let assigned = assignModelAliases (includeModelsInOrder schema incl)
      aliasAt i = snd (assigned !! i)
   in IncludeAliases
        { iaRoot = aliasAt 0,
          iaChild = aliasAt 1,
          iaGrand =
            if length assigned > 2
              then Just (aliasAt 2)
              else Nothing
        }

includeModelsInOrder :: Schema -> ModelInclude -> [Model]
includeModelsInOrder schema incl =
  case includeTree incl of
    [] ->
      error $
        "includeModelsInOrder: include "
          <> T.unpack (includeName incl)
          <> " has empty tree"
    edges ->
      modelsOnPath schema (lookupModel schema (includeRootModel incl)) edges

modelsOnPath :: Schema -> Model -> [IncludeTree] -> [Model]
modelsOnPath schema from edges =
  case edges of
    [] -> [from]
    (edge : _) ->
      let rel = lookupRelation from (includeRelation edge)
          child = lookupModel schema (relToModel rel)
       in from : case includeChildren edge of
            [] -> [child]
            childEdges -> modelsOnPath schema child childEdges

assignModelAliases :: [Model] -> [(Model, Text)]
assignModelAliases models = go models []
  where
    go [] _ = []
    go (model : rest) taken =
      case allocateJoinAlias model taken of
        Nothing ->
          error $
            "assignModelAliases: exhausted alias candidates for "
              <> T.unpack (modelName model)
        Just alias ->
          (model, alias) : go rest (alias : taken)

allocateJoinAlias :: Model -> [Text] -> Maybe Text
allocateJoinAlias model taken =
  find (`notElem` taken) (aliasCandidates model)

aliasCandidates :: Model -> [Text]
aliasCandidates model =
  nub $
    filter (not . T.null) $
      firstLetter
        : [abbrevCamelAlias name]
        ++ prefixes
        ++ numbered
        ++ modelNumbered
  where
    name = modelName model
    lowerName = lowerFirst name
    firstLetter = T.toLower (T.take 1 name)
    prefixes = [T.take n lowerName | n <- [2 .. T.length lowerName]]
    numbered = [firstLetter <> T.pack (show (i :: Int)) | i <- [2 .. (20 :: Int)]]
    modelNumbered = [lowerName <> T.pack (show (i :: Int)) | i <- [1 .. (10 :: Int)]]

abbrevCamelAlias :: Text -> Text
abbrevCamelAlias name =
  case T.uncons name of
    Nothing -> name
    Just (c, rest) ->
      case T.find isUpper rest of
        Just u -> T.cons (toLower c) (T.singleton (toLower u))
        Nothing -> T.singleton (toLower c)

lookupModel :: Schema -> Text -> Model
lookupModel schema name =
  case find ((== name) . modelName) (schemaModels schema) of
    Just m -> m
    Nothing -> error $ "JoinAlias: unknown model " <> T.unpack name

lookupRelation :: Model -> Text -> RelationSpec
lookupRelation model name =
  case find ((== name) . relName) (modelRelations model) of
    Just r -> r
    Nothing ->
      error $
        "JoinAlias: unknown relation "
          <> T.unpack name
          <> " on "
          <> T.unpack (modelName model)

lowerFirst :: Text -> Text
lowerFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toLower c) rest
