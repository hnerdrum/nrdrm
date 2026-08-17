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
    findUnique,
    findUniqueOrFail,
    applyRootFilter,
  )
where

import Control.Exception (throw)
import Data.Kind (Type)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField)
import ORM.Core (Entity (..), PrimaryKeyType)
import ORM.Db (Db (..))
import ORM.Errors (ORMError (..), requireFound)
import ORM.JoinChain (JoinChain, rootAlias, whereJoin)
import qualified ORM.JoinChain as JoinChain
import qualified ORM.Operations as Ops
import ORM.Query
  ( QueryBuilder,
    queryLimit,
    queryOffset,
    queryOrderBy,
    queryWhereConditions,
    queryWhereParams,
    selectAll,
    whereEq,
  )

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

findMany ::
  (ExecuteInclude root include result) =>
  include ->
  (QueryBuilder root -> QueryBuilder root) ->
  Db [result]
findMany = executeInclude

findUnique ::
  forall root include result.
  ( Entity root,
    ToField (PrimaryKeyType root),
    ExecuteInclude root include result
  ) =>
  include ->
  PrimaryKeyType root ->
  Db (Maybe result)
findUnique include pk = do
  results <- findMany include (whereEq (primaryKey @root) pk)
  pure $ case results of
    [] -> Nothing
    (row : _) -> Just row

findUniqueOrFail ::
  forall root include result.
  ( Entity root,
    ToField (PrimaryKeyType root),
    Show (PrimaryKeyType root),
    ExecuteInclude root include result
  ) =>
  include ->
  PrimaryKeyType root ->
  Db (Either ORMError result)
findUniqueOrFail include pk = do
  result <- findUnique @root include pk
  pure $
    requireFound result $
      RecordNotFound $
        "Record not found with primary key: " <> Text.pack (show pk)

applyRootFilter ::
  forall root.
  (Entity root) =>
  JoinChain root ->
  (QueryBuilder root -> QueryBuilder root) ->
  JoinChain root
applyRootFilter chain modifier =
  let qb = modifier (selectAll @root)
   in case includePagingError qb of
        Just err -> throw err
        Nothing ->
          let alias = rootAlias chain
              prefixedWhere = map (prefixWhereCondition alias) (queryWhereConditions qb)
           in foldl applyWhere chain (zip prefixedWhere (queryWhereParams qb))
  where
    applyWhere c (condition, param) = whereJoin condition [param] c

includePagingError :: QueryBuilder table -> Maybe ORMError
includePagingError qb
  | isJust (queryLimit qb)
      || isJust (queryOffset qb)
      || isJust (queryOrderBy qb) =
      Just $
        UnsupportedIncludeModifier
          "limit, offset, and orderBy are not supported on include queries"
  | otherwise = Nothing

prefixWhereCondition :: Text -> Text -> Text
prefixWhereCondition alias condition = alias <> "." <> condition
