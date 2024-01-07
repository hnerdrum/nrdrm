{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Http.Headers
  (
    SetCookieHeader
  ) where

import Servant

-- TODO: use text?
type SetCookieHeader v = Headers '[ Header SetCookieHeaderName String ] v

type family SetCookieHeaderName where
  SetCookieHeaderName = "Set-Cookie"