{-# LANGUAGE OverloadedStrings #-}

module Logger
    (
      initializeLogEnv
    , logInfo
    , logWarn
    , logError
    ) where

import Data.Text
import Katip
import System.IO (stdout)

initializeLogEnv :: IO LogEnv
initializeLogEnv = do
    logEnv <- initLogEnv "recipes-app" "production"
    jsonScribe <- mkHandleScribe ColorIfTerminal stdout (permitItem InfoS) V2
    registerScribe "stdout" jsonScribe defaultScribeSettings logEnv

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