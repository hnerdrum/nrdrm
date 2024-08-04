module Http.Headers
  (
    SetCookieHeader
  , CookieHeader
  ) where

import Data.Text ( Text )
import Servant ( Headers, Header )

type SetCookieHeader v = Headers '[ Header SetCookieHeaderName Text ] v

type family SetCookieHeaderName where
  SetCookieHeaderName = "Set-Cookie"

type CookieHeader = "Cookie"