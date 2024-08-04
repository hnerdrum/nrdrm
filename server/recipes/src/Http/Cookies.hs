module Http.Cookies
(
  getCookie
, authCookie
, authCookieName
) where

import qualified Data.Text as T hiding (map)

authCookie :: T.Text -> T.Text
authCookie value = authCookieName <> "=" <> value <> "; Max-Age=" <> ((T.pack . show) authCookieMaxAge) <> "; Path=/; HttpOnly; SameSite=Lax;"

authCookieName :: T.Text
authCookieName = "recipes-login"

authCookieMaxAge :: Int
authCookieMaxAge = 86400 -- 24 hours

getCookie :: T.Text -> Maybe T.Text -> Maybe T.Text
getCookie name maybeCookies = do
  parsed <- fmap parseCookies maybeCookies
  lookup name parsed

parseCookies :: T.Text -> [(T.Text, T.Text)]
parseCookies cookieHeader = map parseCookie (splitCookie cookieHeader)

parseCookie :: T.Text -> (T.Text, T.Text)
parseCookie cookie = case T.breakOn "=" cookie of
    (key, val) -> (T.strip key, T.strip $ T.drop 1 val)

splitCookie :: T.Text -> [T.Text]
splitCookie = T.splitOn ";" . T.strip