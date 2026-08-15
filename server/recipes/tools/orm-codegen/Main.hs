{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text (Text, pack)
import qualified Data.Text.IO as TIO
import ORM.Codegen.Run (GenOutput (..), allOutputs, checkOutputs, codegenSchemas, writeOutputs)
import ORM.Codegen.Validate (ValidationError (..), validateSchema)
import System.Directory (getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)

main :: IO ()
main = do
  root <- getCurrentDirectory
  args <- getArgs
  case args of
    ("--check" : _) -> runCheck root
    ("--list" : _) -> runList
    _ -> runWrite root

runWrite :: FilePath -> IO ()
runWrite root = do
  validateOrExit
  writeOutputs root
  TIO.putStrLn $ "Wrote " <> pack (show (length allOutputs)) <> " generated files."

runCheck :: FilePath -> IO ()
runCheck root = do
  validateOrExit
  stale <- checkOutputs root
  case stale of
    [] -> exitSuccess
    paths -> do
      TIO.putStrLn "Generated ORM files are out of date. Run `make orm-gen` and commit."
      mapM_ (TIO.putStrLn . ("  " <>)) (pack <$> paths)
      exitFailure

runList :: IO ()
runList = mapM_ (TIO.putStrLn . pack . outputPath) allOutputs

validateOrExit :: IO ()
validateOrExit =
  case concatMap validateSchema codegenSchemas of
    [] -> pure ()
    errs -> do
      TIO.putStrLn "Schema validation failed:"
      mapM_ (TIO.putStrLn . ("  " <>) . formatValidationError) errs
      exitFailure

formatValidationError :: ValidationError -> Text
formatValidationError err = pack (show err)
