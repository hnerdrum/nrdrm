module API.Errors
    (
      ToServantError
    , toServerError
    ) where

import Servant

class ToServantError a where
  toServerError :: a -> ServerError
