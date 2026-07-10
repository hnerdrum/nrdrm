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
    applyRootFilter,
  )
where

import Data.Kind (Type)
import Data.Pool (Pool)
import Data.Text (Text)
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.FromRow (FromRow)
import ORM.Core (Entity (..))
import ORM.JoinChain (JoinChain, rootAlias, whereJoin)
import qualified ORM.JoinChain as JoinChain
import ORM.Operations (findMany)
import ORM.Query (QueryBuilder, queryWhereConditions, queryWhereParams, selectAll)

class IncludesJoin include where
  includesJoin :: include -> Bool

class IncludesJoin include => BuildJoinChain root include | include -> root where
  type JoinFlatRow include :: Type
  buildJoinChain :: include -> JoinChain root

class IncludesJoin include => NestInclude include result | include -> result where
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
        roots <- findMany @root @(RootRow include) pool modifier
        pure $ map (wrapRoot include) roots

findManyWith :: ExecuteInclude root include result => Pool Connection -> include -> (QueryBuilder root -> QueryBuilder root) -> IO [result]
findManyWith = executeInclude

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
