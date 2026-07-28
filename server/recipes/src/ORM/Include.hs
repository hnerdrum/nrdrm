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
    findMany,
    findManyConn,
    findAll,
    findAllConn,
    findUnique,
    findUniqueConn,
    findUniqueOrError,
    findUniqueOrErrorConn,
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

findManyConn ::
  (ExecuteInclude root include result) =>
  Connection ->
  include ->
  (QueryBuilder root -> QueryBuilder root) ->
  IO [result]
findManyConn = executeInclude

findMany ::
  (ExecuteInclude root include result) =>
  Pool Connection ->
  include ->
  (QueryBuilder root -> QueryBuilder root) ->
  IO [result]
findMany pool include modifier =
  withResource pool $ \conn -> findManyConn conn include modifier

findAllConn ::
  forall root include result.
  (ExecuteInclude root include result) =>
  Connection ->
  include ->
  IO [result]
findAllConn conn include =
  findManyConn @root conn include Prelude.id

findAll ::
  forall root include result.
  (ExecuteInclude root include result) =>
  Pool Connection ->
  include ->
  IO [result]
findAll pool include =
  withResource pool $ \conn -> findAllConn @root conn include

findUniqueConn ::
  forall root include result.
  ( ExecuteInclude root include result,
    Entity root,
    ToField (PrimaryKeyType root)
  ) =>
  Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Maybe result)
findUniqueConn conn include pk = do
  results <- findManyConn @root conn include (whereEq (primaryKey @root) pk)
  pure $ case results of
    [] -> Nothing
    (row : _) -> Just row

findUnique ::
  forall root include result.
  ( ExecuteInclude root include result,
    Entity root,
    ToField (PrimaryKeyType root)
  ) =>
  Pool Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Maybe result)
findUnique pool include pk =
  withResource pool $ \conn -> findUniqueConn @root conn include pk

findUniqueOrErrorConn ::
  forall root include result.
  ( ExecuteInclude root include result,
    Entity root,
    ToField (PrimaryKeyType root),
    Show (PrimaryKeyType root)
  ) =>
  Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Either ORMError result)
findUniqueOrErrorConn conn include pk = do
  result <- findUniqueConn @root conn include pk
  case result of
    Nothing ->
      pure $
        Left $
          RecordNotFound $
            "Record not found with primary key: " <> Text.pack (show pk)
    Just row -> pure (Right row)

findUniqueOrError ::
  forall root include result.
  ( ExecuteInclude root include result,
    Entity root,
    ToField (PrimaryKeyType root),
    Show (PrimaryKeyType root)
  ) =>
  Pool Connection ->
  include ->
  PrimaryKeyType root ->
  IO (Either ORMError result)
findUniqueOrError pool include pk =
  withResource pool $ \conn -> findUniqueOrErrorConn @root conn include pk

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
