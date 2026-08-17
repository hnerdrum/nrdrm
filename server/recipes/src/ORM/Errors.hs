module ORM.Errors
  ( ORMError (..),
    requireFound,
    parseSingleton,
  )
where

import Control.Exception (Exception)
import Data.Text (Text)

data ORMError
  = RecordNotFound Text
  | MultipleRecordsFound Text
  | UniqueViolation Text
  | DatabaseError Text
  | UnsupportedIncludeModifier Text
  deriving (Show, Eq)

instance Exception ORMError

requireFound :: Maybe a -> ORMError -> Either ORMError a
requireFound Nothing err = Left err
requireFound (Just value) _ = Right value

parseSingleton :: [a] -> ORMError -> ORMError -> Either ORMError a
parseSingleton rows notFoundErr multipleErr =
  case rows of
    [] -> Left notFoundErr
    [row] -> Right row
    _ -> Left multipleErr
