{-# LANGUAGE OverloadedStrings #-}

module Logger
    (
      initializeLogEnv
    , logInfo
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
logInfo logEnv namespace message =
  runKatipT logEnv $ do
    logMsg namespace InfoS (logStr message)
