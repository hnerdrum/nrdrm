module ORM.Errors
  ( ORMError (..),
  )
where

import Data.Text (Text)

data ORMError
  = RecordNotFound Text
  | MultipleRecordsFound Text
  deriving (Show, Eq)
