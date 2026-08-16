{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text (Text, pack)
import qualified Data.Text.IO as TIO
import ORM.Codegen.IR (Schema (..))
import ORM.Codegen.RecipeTarget (prodTarget)
import ORM.Codegen.Run (GenOutput (..), allOutputs, checkOutputs, schemasForTargets, writeOutputs)
import ORM.Codegen.Target (CodegenTarget, testTarget)
import ORM.Codegen.Validate (ValidationError (..), validateSchema)
import System.Directory (getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)

main :: IO ()
main = do
  root <- getCurrentDirectory
  args <- getArgs
  let targets = [testTarget, prodTarget]
  case args of
    ("--check" : _) -> runCheck root targets
    ("--list" : _) -> runList targets
    _ -> runWrite root targets

runWrite :: FilePath -> [CodegenTarget] -> IO ()
runWrite root targets = do
  validateOrExit (schemasForTargets targets)
  writeOutputs root targets
  TIO.putStrLn $ "Wrote " <> pack (show (length (allOutputs targets))) <> " generated files."

runCheck :: FilePath -> [CodegenTarget] -> IO ()
runCheck root targets = do
  validateOrExit (schemasForTargets targets)
  stale <- checkOutputs root targets
  case stale of
    [] -> exitSuccess
    paths -> do
      TIO.putStrLn "Generated ORM files are out of date. Run `make orm-gen`."
      mapM_ (TIO.putStrLn . ("  " <>)) (pack <$> paths)
      exitFailure

runList :: [CodegenTarget] -> IO ()
runList targets = mapM_ (TIO.putStrLn . pack . outputPath) (allOutputs targets)

validateOrExit :: [Schema] -> IO ()
validateOrExit schemas =
  case concatMap validateSchema schemas of
    [] -> pure ()
    errs -> do
      TIO.putStrLn "Schema validation failed:"
      mapM_ (TIO.putStrLn . ("  " <>) . formatValidationError) errs
      exitFailure

formatValidationError :: ValidationError -> Text
formatValidationError err = pack (show err)
