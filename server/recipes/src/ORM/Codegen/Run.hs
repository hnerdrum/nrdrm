module ORM.Codegen.Run
  ( GenOutput (..),
    allOutputs,
    checkOutputs,
    writeOutputs,
    codegenSchemas,
  )
where

import Data.Text (Text, strip)
import qualified Data.Text.IO as TIO
import ORM.Codegen.IR (Schema (..))
import ORM.Codegen.Target
  ( GenOutput (..),
    allTargets,
    targetOutputs,
    targetSchemas,
  )
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.FilePath (takeDirectory, (</>))

codegenSchemas :: [Schema]
codegenSchemas = targetSchemas

allOutputs :: [GenOutput]
allOutputs = concatMap targetOutputs allTargets

writeOutputs :: FilePath -> IO ()
writeOutputs root = mapM_ (writeOutput root) allOutputs

checkOutputs :: FilePath -> IO [FilePath]
checkOutputs root = filterMismatches root allOutputs

writeOutput :: FilePath -> GenOutput -> IO ()
writeOutput root GenOutput {outputPath = path, outputText = text} = do
  let fullPath = root </> path
  createDirectoryIfMissing True (takeDirectory fullPath)
  TIO.writeFile fullPath text

filterMismatches :: FilePath -> [GenOutput] -> IO [FilePath]
filterMismatches root = foldr go (pure [])
  where
    go GenOutput {outputPath = path, outputText = expected} acc = do
      mismatches <- acc
      let fullPath = root </> path
      exists <- doesFileExist fullPath
      if not exists
        then pure (path : mismatches)
        else do
          actual <- TIO.readFile fullPath
          pure (if stripText actual == stripText expected then mismatches else path : mismatches)

stripText :: Text -> Text
stripText = strip
