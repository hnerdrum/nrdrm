{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module ORM.JoinChain
  ( JoinChain,
    JoinedTable (..),
    startJoinChain,
    buildJoinChainFromHasMany,
    selectColumns,
    selectFields,
    whereJoin,
    col,
    aliasedField,
    buildJoinQuery,
    runJoinChain,
    rootAlias,
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
import ORM.Relation (HasMany (..), JoinType (..))

data JoinedTable = JoinedTable
  { jtTable :: Text,
    jtAlias :: Text,
    jtJoinType :: JoinType,
    jtOnLeft :: Text,
    jtOnRight :: Text
  }
  deriving (Show, Eq)

data JoinChain root = JoinChain
  { jcRoot :: Text,
    jcRootAlias :: Text,
    jcJoins :: [JoinedTable],
    jcSelect :: [Text],
    jcWhere :: [Text],
    jcParams :: [Action]
  }
  deriving (Show)

startJoinChain ::
  forall root.
  (Entity root) =>
  Text ->
  JoinChain root
startJoinChain alias =
  JoinChain
    { jcRoot = tableName @root,
      jcRootAlias = alias,
      jcJoins = [],
      jcSelect = [],
      jcWhere = [],
      jcParams = []
    }

buildJoinChainFromHasMany ::
  forall parent child key.
  (Entity parent, Entity child) =>
  HasMany parent child key ->
  Text ->
  Text ->
  JoinChain parent
buildJoinChainFromHasMany rel parentAlias childAlias =
  (startJoinChain @parent parentAlias)
    { jcJoins =
        [ JoinedTable
            { jtTable = tableName @child,
              jtAlias = childAlias,
              jtJoinType = joinType rel,
              jtOnLeft = parentAlias <> "." <> fieldColumn (localKey rel),
              jtOnRight = childAlias <> "." <> fieldColumn (foreignKey rel)
            }
        ]
    }

selectColumns ::
  [Text] ->
  JoinChain root ->
  JoinChain root
selectColumns cols chain =
  chain {jcSelect = cols}

selectFields ::
  [(Text, [Field table a])] ->
  JoinChain root ->
  JoinChain root
selectFields fieldGroups chain =
  let columns = concatMap (\(alias, fields) -> map (col alias) fields) fieldGroups
   in chain {jcSelect = columns}

whereJoin ::
  Text ->
  [Action] ->
  JoinChain root ->
  JoinChain root
whereJoin condition params chain =
  chain
    { jcWhere = jcWhere chain ++ [condition],
      jcParams = jcParams chain ++ params
    }

col :: Text -> Field table a -> Text
col alias field = alias <> "." <> fieldColumn field

aliasedField :: Maybe Text -> Field table a -> Text
aliasedField maybeAlias field =
  case maybeAlias of
    Nothing -> fieldColumn field
    Just alias -> col alias field

joinTypeText :: JoinType -> Text
joinTypeText LeftJoin = "LEFT JOIN"
joinTypeText InnerJoin = "INNER JOIN"
joinTypeText RightJoin = "RIGHT JOIN"

buildJoinClause :: JoinedTable -> Text
buildJoinClause jt =
  joinTypeText (jtJoinType jt)
    <> " "
    <> jtTable jt
    <> " "
    <> jtAlias jt
    <> " ON "
    <> jtOnLeft jt
    <> " = "
    <> jtOnRight jt

buildJoinQuery :: JoinChain root -> (Query, [Action])
buildJoinQuery jc =
  let rootRef = jcRoot jc <> " " <> jcRootAlias jc
      selectClause =
        if null (jcSelect jc)
          then "*"
          else Text.intercalate ", " (jcSelect jc)
      joinClauses = map buildJoinClause (jcJoins jc)
      fromClause = " FROM " <> rootRef <> " " <> Text.intercalate " " joinClauses
      whereClause =
        if null (jcWhere jc)
          then ""
          else " WHERE " <> Text.intercalate " AND " (jcWhere jc)
      queryText = "SELECT " <> selectClause <> fromClause <> whereClause
   in (Query (TE.encodeUtf8 queryText), jcParams jc)

runJoinChain ::
  forall result root.
  (FromRow result) =>
  Pool Connection ->
  JoinChain root ->
  IO [result]
runJoinChain pool chain =
  withResource pool $ \conn -> do
    let (query, params) = buildJoinQuery chain
    PGSimple.queryWith fromRow conn query params

rootAlias :: JoinChain root -> Text
rootAlias = jcRootAlias
