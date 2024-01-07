{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Http.Headers
  (
    SetCookieHeader
  ) where

import Data.Text
import Servant

type SetCookieHeader v = Headers '[ Header SetCookieHeaderName Text ] v

type family SetCookieHeaderName where
  SetCookieHeaderName = "Set-Cookie"