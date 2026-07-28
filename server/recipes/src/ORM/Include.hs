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
    findAll,
    findUnique,
    findUniqueOrError,
    applyRootFilter,
  )
where

import Data.Kind (Type)
import Data.Pool (Pool)
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
    Pool Connection ->
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
  executeInclude pool include modifier
    | includesJoin include = do
        let chain = applyRootFilter (buildJoinChain include) modifier
        flatRows <- JoinChain.runJoinChain @(JoinFlatRow include) pool chain
        pure $ nestRows include flatRows
    | otherwise = do
        roots <- Ops.findMany @root @(RootRow include) pool modifier
        pure $ map (wrapRoot include) roots

findMany ::
  (ExecuteInclude root include result) =>
  Pool Connection ->
  include ->
  (QueryBuilder root -> QueryBuilder root) ->
  IO [result]
findMany = executeInclude

findAll ::
  forall root include result.
  (ExecuteInclude root include result) =>
  Pool Connection ->
  include ->
  IO [result]
findAll pool include =
  findMany @root pool include Prelude.id

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
findUnique pool include pk = do
  results <- findMany @root pool include (whereEq (primaryKey @root) pk)
  pure $ case results of
    [] -> Nothing
    (row : _) -> Just row

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
findUniqueOrError pool include pk = do
  result <- findUnique @root pool include pk
  case result of
    Nothing ->
      pure $
        Left $
          RecordNotFound $
            "Record not found with primary key: " <> Text.pack (show pk)
    Just row -> pure (Right row)

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
