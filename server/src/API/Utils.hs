{-# LANGUAGE OverloadedStrings #-}

module API.Utils
  (
    resolveEitherAppResult
  , liftMaybe
  ) where

import App (AppM)
import Servant

resolveEitherAppResult :: (b -> AppM c) -> (a -> AppM c) -> Either b a -> AppM c
resolveEitherAppResult leftAction rightAction eitherValue = case eitherValue of
    Right a -> rightAction a
    Left b -> leftAction b

liftMaybe :: Maybe a -> AppM a
liftMaybe (Just x) = return x
liftMaybe Nothing  = throwError err403 { errBody = "Unauthorized" }