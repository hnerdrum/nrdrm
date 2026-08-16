{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}

module ORM.Include
  ( IncludesJoin (..),
    BuildJoinChain (..),
    NestInclude (..),
    ExecuteInclude (..),
    findManyWith,
    findAllWith,
    findUniqueWith,
    findUniqueOrErrorWith,
    applyRootFilter,
  )
where

import Data.Kind (Type)
import Data.Text (Text)
import qualified Data.Text as Text
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField)
import ORM.Core (Entity (..), PrimaryKeyType)
import ORM.Db (Db (..))
import ORM.Errors (ORMError (..))
import ORM.JoinChain (JoinChain, rootAlias, whereJoin)
import qualified ORM.JoinChain as JoinChain
import qualified ORM.Operations as Ops
import ORM.Query (QueryBuilder, queryWhereConditions, queryWhereParams, selectAll, whereEq)

class IncludesJoin include where
  includesJoin :: include -> Bool

class (IncludesJoin include) => BuildJoinChain root include | include -> root where
  type JoinFlatRow include :: Type
  buildJoinChain :: include -> JoinChain root

class (IncludesJoin include) => NestInclude include result | include -> result where
  type RootRow include :: Type
  nestRows :: include -> [JoinFlatRow include] -> [result]
  wrapRoot :: include -> RootRow include -> result

class ExecuteInclude root include result | include -> result where
  executeInclude ::
    include ->
    (QueryBuilder root -> QueryBuilder root) ->
    Db [result]

instance
  ( Entity root,
    BuildJoinChain root include,
    NestInclude include result,
    FromRow (JoinFlatRow include),
    FromRow (RootRow include)
  ) =>
  ExecuteInclude root include result
  where
  executeInclude include modifier
    | includesJoin include = do
        let chain = applyRootFilter (buildJoinChain include) modifier
        flatRows <- JoinChain.runJoinChain @(JoinFlatRow include) chain
        pure $ nestRows include flatRows
    | otherwise = do
        roots <- Ops.findMany @root @(RootRow include) modifier
        pure $ map (wrapRoot include) roots

findManyWith ::
  (ExecuteInclude root include result) =>
  include ->
  (QueryBuilder root -> QueryBuilder root) ->
  Db [result]
findManyWith = executeInclude

findAllWith ::
  forall root include result.
  (ExecuteInclude root include result) =>
  include ->
  Db [result]
findAllWith include = findManyWith @root include Prelude.id

findUniqueWith ::
  forall root include result.
  ( Entity root,
    ToField (PrimaryKeyType root),
    BuildJoinChain root include,
    NestInclude include result,
    FromRow (JoinFlatRow include),
    FromRow (RootRow include)
  ) =>
  include ->
  PrimaryKeyType root ->
  Db (Maybe result)
findUniqueWith include pk
  | includesJoin include = do
      let chain =
            JoinChain.limitJoin 1 $
              applyRootFilter (buildJoinChain include) (whereEq (primaryKey @root) pk)
      flatRows <- JoinChain.runJoinChain @(JoinFlatRow include) chain
      pure $ case nestRows include flatRows of
        [] -> Nothing
        (row : _) -> Just row
  | otherwise = do
      mRoot <- Ops.findUnique @root @(RootRow include) pk
      pure $ fmap (wrapRoot include) mRoot

findUniqueOrErrorWith ::
  forall root include result.
  ( Entity root,
    ToField (PrimaryKeyType root),
    Show (PrimaryKeyType root),
    BuildJoinChain root include,
    NestInclude include result,
    FromRow (JoinFlatRow include),
    FromRow (RootRow include)
  ) =>
  include ->
  PrimaryKeyType root ->
  Db (Either ORMError result)
findUniqueOrErrorWith include pk = do
  result <- findUniqueWith @root include pk
  case result of
    Nothing ->
      pure $
        Left $
          RecordNotFound $
            "Record not found with primary key: " <> Text.pack (show pk)
    Just row -> pure $ Right row

applyRootFilter ::
  forall root.
  (Entity root) =>
  JoinChain root ->
  (QueryBuilder root -> QueryBuilder root) ->
  JoinChain root
applyRootFilter chain modifier =
  let qb = modifier (selectAll @root)
      alias = rootAlias chain
      prefixedWhere = map (prefixWhereCondition alias) (queryWhereConditions qb)
   in foldl applyWhere chain (zip prefixedWhere (queryWhereParams qb))
  where
    applyWhere c (condition, param) = whereJoin condition [param] c

prefixWhereCondition :: Text -> Text -> Text
prefixWhereCondition alias condition = alias <> "." <> condition
