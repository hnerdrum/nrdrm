module Config
  ( AppConfig (..),
    loadConfig,
  )
where

import Configuration.Dotenv (defaultConfig, loadFile)
import Control.Exception (catch)
import Data.Maybe (fromMaybe)
import Data.Text (Text, pack)
import Data.Time
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data AppConfig = AppConfig
  { port :: Int,
    databaseUrl :: String,
    bootTime :: Text,
    apiVersion :: Text
  }
  deriving (Show)

loadEnv :: IO ()
loadEnv = catch (loadFile defaultConfig) handleError
  where
    handleError :: IOError -> IO ()
    handleError _ = putStrLn "Warning: .env file not found, using environment variables only"

loadConfig :: IO AppConfig
loadConfig = do
  loadEnv
  loadedPort <- lookupEnv "PORT"
  loadedDbUrl <- lookupEnv "DATABASE_URL"
  loadedBuildId <- lookupEnv "BUILD_ID"
  currentTime <- getCurrentTime
  let buildId = fromMaybe "dev" loadedBuildId
      formattedTime = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ" currentTime
  return $
    AppConfig
      { port = fromMaybe 8000 $ parsePort loadedPort,
        databaseUrl = fromMaybe "" loadedDbUrl,
        bootTime = pack formattedTime,
        apiVersion = pack (take 7 buildId)
      }

parsePort :: Maybe String -> Maybe Int
parsePort = (readMaybe =<<)
