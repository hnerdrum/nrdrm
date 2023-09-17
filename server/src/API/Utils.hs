module API.Utils
    (
      handleEither
    ) where

import App (AppM)

handleEither :: (b -> AppM a) -> Either b a -> AppM a
handleEither action eitherValue = case eitherValue of
    Right a -> return a
    Left b -> action b