{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.Join
  ( JoinBuilder,
    JoinType (..),
    leftJoin,
    innerJoin,
    on,
    selectFrom,
    runJoin,
    as,
    selectColumns,
    selectFields,
    whereJoin,
    aliasedField,
    col,
  )
where

import Data.Pool (Pool, withResource)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple (Connection)
import qualified Database.PostgreSQL.Simple as PGSimple
import Database.PostgreSQL.Simple.FromRow (FromRow, fromRow)
import Database.PostgreSQL.Simple.ToField (Action)
import Database.PostgreSQL.Simple.Types (Query (..))
import ORM.Core (Entity (..), Field (..))
import ORM.JoinChain (aliasedField, col)
import ORM.Relation (JoinType (..))

data JoinBuilder leftTable rightTable = JoinBuilder
  { jbLeftTable :: Text,
    jbLeftAlias :: Maybe Text,
    jbRightTable :: Text,
    jbRightAlias :: Maybe Text,
    jbJoinType :: JoinType,
    jbOnConditions :: [(Text, Text)],
    jbSelectColumns :: Maybe [Text],
    jbWhere :: [Text],
    jbParams :: [Action]
  }

selectFrom ::
  forall leftTable rightTable.
  (Entity leftTable, Entity rightTable) =>
  JoinBuilder leftTable rightTable
selectFrom =
  JoinBuilder
    { jbLeftTable = tableName @leftTable,
      jbLeftAlias = Nothing,
      jbRightTable = tableName @rightTable,
      jbRightAlias = Nothing,
      jbJoinType = LeftJoin,
      jbOnConditions = [],
      jbSelectColumns = Nothing,
      jbWhere = [],
      jbParams = []
    }

leftJoin ::
  forall leftTable rightTable.
  (Entity leftTable, Entity rightTable) =>
  JoinBuilder leftTable rightTable
leftJoin = (selectFrom @leftTable @rightTable) {jbJoinType = LeftJoin}

innerJoin ::
  forall leftTable rightTable.
  (Entity leftTable, Entity rightTable) =>
  JoinBuilder leftTable rightTable
innerJoin = (selectFrom @leftTable @rightTable) {jbJoinType = InnerJoin}

as ::
  (Text, Text) ->
  JoinBuilder leftTable rightTable ->
  JoinBuilder leftTable rightTable
as (leftAlias, rightAlias) builder =
  builder
    { jbLeftAlias = Just leftAlias,
      jbRightAlias = Just rightAlias
    }

selectColumns ::
  [Text] ->
  JoinBuilder leftTable rightTable ->
  JoinBuilder leftTable rightTable
selectColumns cols builder =
  builder {jbSelectColumns = Just cols}

whereJoin ::
  Text ->
  [Action] ->
  JoinBuilder leftTable rightTable ->
  JoinBuilder leftTable rightTable
whereJoin condition params builder =
  builder
    { jbWhere = jbWhere builder ++ [condition],
      jbParams = jbParams builder ++ params
    }

selectFields ::
  JoinBuilder leftTable rightTable ->
  [(Maybe Text, [Field table a])] ->
  JoinBuilder leftTable rightTable
selectFields builder fieldGroups =
  let columns = concatMap (\(maybeAlias, fields) -> map (aliasedField maybeAlias) fields) fieldGroups
   in builder {jbSelectColumns = Just columns}

on ::
  Field leftTable a ->
  Field rightTable a ->
  JoinBuilder leftTable rightTable ->
  JoinBuilder leftTable rightTable
on leftField rightField builder =
  builder
    { jbOnConditions =
        jbOnConditions builder
          ++ [(fieldColumn leftField, fieldColumn rightField)]
    }

joinTypeText :: JoinType -> Text
joinTypeText LeftJoin = "LEFT JOIN"
joinTypeText InnerJoin = "INNER JOIN"
joinTypeText RightJoin = "RIGHT JOIN"

buildJoinQuery :: JoinBuilder leftTable rightTable -> (Query, [Action])
buildJoinQuery jb =
  let leftTableRef = case jbLeftAlias jb of
        Nothing -> jbLeftTable jb
        Just alias -> jbLeftTable jb <> " " <> alias

      rightTableRef = case jbRightAlias jb of
        Nothing -> jbRightTable jb
        Just alias -> jbRightTable jb <> " " <> alias

      leftPrefix = case jbLeftAlias jb of
        Nothing -> jbLeftTable jb
        Just alias -> alias

      rightPrefix = case jbRightAlias jb of
        Nothing -> jbRightTable jb
        Just alias -> alias

      selectClause = case jbSelectColumns jb of
        Nothing -> "*"
        Just cols -> Text.intercalate ", " cols

      onClause =
        if null (jbOnConditions jb)
          then ""
          else
            " ON "
              <> Text.intercalate
                " AND "
                [leftPrefix <> "." <> left <> " = " <> rightPrefix <> "." <> right | (left, right) <- jbOnConditions jb]

      whereClause =
        if null (jbWhere jb)
          then ""
          else " WHERE " <> Text.intercalate " AND " (jbWhere jb)

      queryText =
        "SELECT "
          <> selectClause
          <> " FROM "
          <> leftTableRef
          <> " "
          <> joinTypeText (jbJoinType jb)
          <> " "
          <> rightTableRef
          <> onClause
          <> whereClause
   in (Query (TE.encodeUtf8 queryText), jbParams jb)

runJoin ::
  (FromRow result) =>
  Pool Connection ->
  JoinBuilder leftTable rightTable ->
  IO [result]
runJoin pool jb =
  withResource pool $ \conn -> do
    let (query, params) = buildJoinQuery jb
    PGSimple.queryWith fromRow conn query params
