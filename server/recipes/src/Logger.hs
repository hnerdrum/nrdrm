module Logger
  ( initializeLogEnv,
    loggingMiddleware,
    logInfo,
    logWarn,
    logError,
  )
where

import Data.Text
import Katip
  ( ColorStrategy (ColorIfTerminal),
    LogEnv,
    Namespace,
    Severity (ErrorS, InfoS, WarningS),
    Verbosity (V2),
    defaultScribeSettings,
    initLogEnv,
    logMsg,
    logStr,
    mkHandleScribe,
    permitItem,
    registerScribe,
    runKatipT,
  )
import Network.Wai (Middleware, rawPathInfo, requestMethod)
import System.IO (stdout)

initializeLogEnv :: IO LogEnv
initializeLogEnv = do
  logEnv <- initLogEnv "recipes" "production"
  jsonScribe <- mkHandleScribe ColorIfTerminal stdout (permitItem InfoS) V2
  registerScribe "stdout" jsonScribe defaultScribeSettings logEnv

loggingMiddleware :: LogEnv -> Middleware
loggingMiddleware logEnv app req res = do
  let method = requestMethod req
  logInfo logEnv "api" $ (pack . show) method <> " " <> (pack . show) (rawPathInfo req)
  app req res

logInfo :: LogEnv -> Namespace -> Text -> IO ()
logInfo = logWithSeverity InfoS

logWarn :: LogEnv -> Namespace -> Text -> IO ()
logWarn = logWithSeverity WarningS

logError :: LogEnv -> Namespace -> Text -> IO ()
logError = logWithSeverity ErrorS

logWithSeverity :: Severity -> LogEnv -> Namespace -> Text -> IO ()
logWithSeverity severity logEnv namespace message =
  runKatipT logEnv $ do
    logMsg namespace severity (logStr message)