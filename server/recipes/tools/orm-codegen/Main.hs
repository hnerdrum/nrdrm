{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text (pack)
import qualified Data.Text.IO as TIO
import ORM.Codegen.Run (GenOutput (..), allOutputs, checkOutputs, writeOutputs)
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
  writeOutputs root
  TIO.putStrLn $ "Wrote " <> pack (show (length allOutputs)) <> " generated files."

runCheck :: FilePath -> IO ()
runCheck root = do
  stale <- checkOutputs root
  case stale of
    [] -> exitSuccess
    paths -> do
      TIO.putStrLn "Generated ORM files are out of date. Run `make orm-gen` and commit."
      mapM_ (TIO.putStrLn . ("  " <>)) (pack <$> paths)
      exitFailure

runList :: IO ()
runList = mapM_ (TIO.putStrLn . pack . outputPath) allOutputs
