module API.Utils
    (
      resolveEitherAppResult
    ) where

import App (AppM)

resolveEitherAppResult :: (b -> AppM a) -> (a -> AppM a) -> Either b a -> AppM a
resolveEitherAppResult leftAction rightAction eitherValue = case eitherValue of
    Right a -> rightAction a
    Left b -> leftAction b