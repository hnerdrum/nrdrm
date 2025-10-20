{-# LANGUAGE AllowAmbiguousTypes #-}

module ORM.Core
  ( Entity (..),
    Column (..),
    SqlType (..),
    Field (..),
    PrimaryKeyType,
  )
where

import Data.Text (Text)
import Database.PostgreSQL.Simple.FromField (FromField)
import Database.PostgreSQL.Simple.ToField (ToField)

class SqlType a where
  toSqlType :: Text

class (FromField a, ToField a) => Column a where
  columnType :: Text

data Field table a = Field
  { fieldName :: Text,
    fieldColumn :: Text
  }

class Entity table where
  tableName :: Text
  primaryKey :: Field table (PrimaryKeyType table)

type family PrimaryKeyType table
