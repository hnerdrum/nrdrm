module ORM.Codegen.TextUtil
  ( lowerFirst,
    upperFirst,
  )
where

import Data.Char (toLower, toUpper)
import Data.Text (Text)
import qualified Data.Text as T

lowerFirst :: Text -> Text
lowerFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toLower c) rest

upperFirst :: Text -> Text
upperFirst t = case T.uncons t of
  Nothing -> t
  Just (c, rest) -> T.cons (toUpper c) rest
