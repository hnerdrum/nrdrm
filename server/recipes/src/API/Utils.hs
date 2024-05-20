{-# LANGUAGE OverloadedStrings #-}

module API.Utils
  (
    resolveEitherAppResult
  , eitherToMaybe
  ) where

import App (AppM)

resolveEitherAppResult :: (b -> AppM c) -> (a -> AppM c) -> Either b a -> AppM c
resolveEitherAppResult leftAction rightAction eitherValue = case eitherValue of
    Right a -> rightAction a
    Left b -> leftAction b

eitherToMaybe :: Either a b -> Maybe b
eitherToMaybe (Right b) = Just b
eitherToMaybe (Left _) = Nothing
