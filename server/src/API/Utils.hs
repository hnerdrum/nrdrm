module API.Utils
    (
      resolveEitherAppResult
    ) where

import App (AppM)

resolveEitherAppResult :: (b -> AppM c) -> (a -> AppM c) -> Either b a -> AppM c
resolveEitherAppResult leftAction rightAction eitherValue = case eitherValue of
    Right a -> rightAction a
    Left b -> leftAction b