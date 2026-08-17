{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.SelectIn
  ( GroupIndex,
    ByPk,
    findByIn,
    emptyGroups,
    indexHasMany,
    lookupGroups,
    emptyByPk,
    indexByPk,
    lookupByPk,
    prepareIncludeRootQuery,
  )
where

import Control.Exception (throw)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Database.PostgreSQL.Simple.FromRow (FromRow)
import Database.PostgreSQL.Simple.ToField (ToField)
import ORM.Core (Entity (..), Field (..))
import ORM.Db (Db)
import ORM.Errors (ORMError (..))
import ORM.Group (groupByKey)
import qualified ORM.Operations as Ops
import ORM.Query
  ( OrderDirection (Asc),
    QueryBuilder,
    WherePred (..),
    orderBy,
    queryOrderBy,
    queryWherePreds,
    whereIn,
  )

newtype GroupIndex k a = GroupIndex (Map k [a])

newtype ByPk k a = ByPk (Map k a)

findByIn ::
  forall table result key.
  (Entity table, FromRow result, ToField key) =>
  Field table key ->
  [key] ->
  Db [result]
findByIn field keys
  | null keys = pure []
  | otherwise =
      Ops.findMany @table @result $
        orderBy (primaryKey @table) Asc . whereIn field keys

emptyGroups :: GroupIndex k a
emptyGroups = GroupIndex Map.empty

indexHasMany :: (Ord k) => (a -> k) -> [a] -> GroupIndex k a
indexHasMany keyFn rows =
  GroupIndex . Map.fromList $
    [(keyFn (head group), group) | group <- groupByKey keyFn rows]

lookupGroups :: (Ord k) => k -> GroupIndex k a -> [a]
lookupGroups key (GroupIndex groups) =
  Map.findWithDefault [] key groups

emptyByPk :: ByPk k a
emptyByPk = ByPk Map.empty

indexByPk :: (Ord k) => (a -> k) -> [a] -> ByPk k a
indexByPk keyFn rows =
  ByPk (Map.fromList [(keyFn row, row) | row <- rows])

lookupByPk :: (Ord k) => k -> ByPk k a -> Maybe a
lookupByPk key (ByPk byPk) =
  Map.lookup key byPk

prepareIncludeRootQuery ::
  forall table.
  (Entity table) =>
  (QueryBuilder table -> QueryBuilder table) ->
  QueryBuilder table ->
  QueryBuilder table
prepareIncludeRootQuery modifier qb0 =
  let qb = modifier qb0
   in case rawWhereError qb of
        Just err -> throw err
        Nothing -> defaultPkOrder @table qb

rawWhereError :: QueryBuilder table -> Maybe ORMError
rawWhereError qb
  | any isRaw (queryWherePreds qb) =
      Just $
        UnsupportedIncludeModifier
          "raw WHERE is not supported on include queries; use whereEq"
  | otherwise = Nothing

isRaw :: WherePred -> Bool
isRaw (WhereRaw _ _) = True
isRaw _ = False

defaultPkOrder ::
  forall table.
  (Entity table) =>
  QueryBuilder table ->
  QueryBuilder table
defaultPkOrder qb =
  case queryOrderBy qb of
    Just _ -> qb
    Nothing -> orderBy (primaryKey @table) Asc qb
