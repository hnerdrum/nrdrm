module Logger
  ( initializeLogEnv,
    loggingMiddleware,
    logInfo,
    logWarn,
    logError,
  )
where

import Data.Aeson (object, (.=))
import Data.Text
import Katip
  ( ColorStrategy (ColorIfTerminal),
    KatipContext,
    LogEnv,
    Namespace,
    Severity (ErrorS, InfoS, WarningS),
    Verbosity (V3),
    defaultScribeSettings,
    initLogEnv,
    logMsg,
    logStr,
    mkHandleScribe,
    mkHandleScribeWithFormatter,
    permitItem,
    registerScribe,
    runKatipContextT,
  )
import Katip.Core (sl)
import Katip.Monadic (katipAddContext)
import Katip.Scribes.Handle (jsonFormat)
import Network.Wai (Middleware, rawPathInfo, requestMethod)
import System.IO (stdout)

initializeLogEnv :: IO LogEnv
initializeLogEnv = do
  logEnv <- initLogEnv "recipes" "production"
  jsonScribe <- mkHandleScribeWithFormatter jsonFormat ColorIfTerminal stdout (permitItem InfoS) V3
  registerScribe "stdout" jsonScribe defaultScribeSettings logEnv

loggingMiddleware :: LogEnv -> Middleware
loggingMiddleware logEnv app req res = do
  let method = requestMethod req
  logInfo logEnv "api" $ (pack . show) method <> " " <> (pack . show) (rawPathInfo req)
  app req res

logInfo :: LogEnv -> Namespace -> Text -> IO ()
logInfo logEnv namespace message = runKatipContextT logEnv () namespace $ do
  logWithSeverity InfoS namespace message

logWarn :: LogEnv -> Namespace -> Text -> IO ()
logWarn logEnv namespace message = runKatipContextT logEnv () namespace $ do
  logWithSeverity WarningS namespace message

logError :: LogEnv -> Namespace -> Text -> IO ()
logError logEnv namespace message = runKatipContextT logEnv () namespace $ do
  logWithSeverity ErrorS namespace message

logWithSeverity :: (KatipContext m) => Severity -> Namespace -> Text -> m ()
logWithSeverity severity namespace message = do
  let payload = object ["message" .= message]
  katipAddContext (sl "context" payload) $
    logMsg namespace severity (logStr message)