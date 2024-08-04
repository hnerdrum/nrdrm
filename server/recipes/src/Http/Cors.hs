module Http.Cors
(
  corsMiddleware
) where

import Data.ByteString.Char8 (pack)
import Network.Wai.Middleware.Cors
    ( CorsResourcePolicy(corsOrigins, corsRequestHeaders, corsMethods),
      cors,
      simpleCorsResourcePolicy )
import Network.Wai (Middleware)

corsMiddleware :: [String] -> Middleware
corsMiddleware allowedOrigins = cors (const $ Just (corsResourcePolicy allowedOrigins))

corsResourcePolicy :: [String] -> CorsResourcePolicy
corsResourcePolicy allowedOrigins = simpleCorsResourcePolicy
   { corsRequestHeaders = ["Content-Type", "Credentials"]
   , corsMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
   , corsOrigins = Just (map pack allowedOrigins, True)
   }