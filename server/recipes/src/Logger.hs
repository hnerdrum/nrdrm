module Logger (info, warn, Logger.error, loggingMiddleware) where

import Control.Monad.Logger.Aeson
import Data.Aeson (Value (Object), object)
import qualified Data.Aeson.KeyMap as KM
import Data.Text hiding (map, show)
import Network.Wai (Middleware, rawPathInfo, requestMethod)

loggingMiddleware :: Middleware
loggingMiddleware app req res = do
  let method = requestMethod req
  info ((pack . show) method <> " " <> (pack . show) (rawPathInfo req)) (object [])
  app req res

info :: Text -> Value -> IO ()
info msg context = runStdoutLoggingT $ do
  logInfo $ toLoggingMessage msg context

warn :: Text -> Value -> IO ()
warn msg context = runStdoutLoggingT $ do
  logWarn $ toLoggingMessage msg context

error :: Text -> Value -> IO ()
error msg context = runStdoutLoggingT $ do
  logError $ toLoggingMessage msg context

toLoggingMessage :: Text -> Value -> Message
toLoggingMessage msg context = msg :# toLoggingContext context

toLoggingContext :: Value -> [SeriesElem]
toLoggingContext (Object obj) = map (uncurry (.=)) $ KM.toList obj
toLoggingContext _ = []