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
    findManyWithConn,
    findAllWith,
    findAllWithConn,
    findUniqueWith,
    findUniqueWithConn,
    findUniqueOrErrorWith,
    findUniqueOrErrorWithConn,
    applyRootFilter,
  )
where

import Data.Kind (Type)
import Data.Pool (Pool, withResource)
import Data.Text (Text)
import qualified Data.Text as Text
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField)
import ORM.Core (Entity (..), PrimaryKeyType)
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
    Connection ->
    include ->
    (QueryBuilder root -> QueryBuilder root) ->
    IO [result]

instance
  ( Entity root,
    BuildJoinChain root include,
    NestInclude include result,
    FromRow (JoinFlatRow include),
    FromRow (RootRow include)
  ) =>
  ExecuteInclude root include result
  where
  executeInclude conn include modifier
    | includesJoin include = do
        let chain = applyRootFilter (buildJoinChain include) modifier
        flatRows <- JoinChain.runJoinChainConn @(JoinFlatRow include) conn chain
        pure $ nestRows include flatRows
    | otherwise = do
        roots <- Ops.findManyConn @root @(RootRow include) conn modifier
        pure $ map (wrapRoot include) roots

findManyWithConn ::
  (ExecuteInclude root include result) =>
  Connection ->
  include ->
  (QueryBuilder root -> QueryBuilder root) ->
  IO [result]
findManyWithConn = executeInclude

findManyWith ::
  (ExecuteInclude root include result) =>
  Pool Connection ->
  include ->
  (QueryBuilder root -> QueryBuilder root) ->
  IO [result]
findManyWith pool include modifier =
  withResource pool $ \conn -> findManyWithConn conn include modifier

findAllWithConn ::
  forall root include result.
  (ExecuteInclude root include result) =>
  Connection ->
  include ->
  IO [result]
findAllWithConn conn include =
  findManyWithConn @root conn include Prelude.id

findAllWith ::
  forall root include result.
  (ExecuteInclude root include result) =>
  Pool Connection ->
  include ->
  IO [result]
findAllWith pool include =
  withResource pool $ \conn -> findAllWithConn @root conn include

findUniqueWithConn ::
  forall root include result.
  ( Entity root,
    ToField (PrimaryKeyType root),
    BuildJoinChain root include,
    NestInclude include result,
    FromRow (JoinFlatRow include),
    FromRow (RootRow include)
  ) =>
  Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Maybe result)
findUniqueWithConn conn include pk
  | includesJoin include = do
      let chain =
            JoinChain.limitJoin 1 $
              applyRootFilter (buildJoinChain include) (whereEq (primaryKey @root) pk)
      flatRows <- JoinChain.runJoinChainConn @(JoinFlatRow include) conn chain
      pure $ case nestRows include flatRows of
        [] -> Nothing
        (row : _) -> Just row
  | otherwise = do
      mRoot <- Ops.findUniqueConn @root @(RootRow include) conn pk
      pure $ fmap (wrapRoot include) mRoot

findUniqueWith ::
  forall root include result.
  ( Entity root,
    ToField (PrimaryKeyType root),
    BuildJoinChain root include,
    NestInclude include result,
    FromRow (JoinFlatRow include),
    FromRow (RootRow include)
  ) =>
  Pool Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Maybe result)
findUniqueWith pool include pk =
  withResource pool $ \conn -> findUniqueWithConn @root conn include pk

findUniqueOrErrorWithConn ::
  forall root include result.
  ( Entity root,
    ToField (PrimaryKeyType root),
    Show (PrimaryKeyType root),
    BuildJoinChain root include,
    NestInclude include result,
    FromRow (JoinFlatRow include),
    FromRow (RootRow include)
  ) =>
  Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Either ORMError result)
findUniqueOrErrorWithConn conn include pk = do
  result <- findUniqueWithConn @root conn include pk
  case result of
    Nothing ->
      pure $
        Left $
          RecordNotFound $
            "Record not found with primary key: " <> Text.pack (show pk)
    Just row -> pure $ Right row

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
  Pool Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Either ORMError result)
findUniqueOrErrorWith pool include pk =
  withResource pool $ \conn -> findUniqueOrErrorWithConn @root conn include pk

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
