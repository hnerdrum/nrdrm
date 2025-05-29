module Config
  ( AppConfig (..),
    loadConfig,
  )
where

import Configuration.Dotenv (defaultConfig, loadFile)
import Control.Exception (catch)
import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data AppConfig = AppConfig
  { port :: Int,
    databaseUrl :: String
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
  return $
    AppConfig
      { port = fromMaybe 8000 $ parsePort loadedPort,
        databaseUrl = fromMaybe "" loadedDbUrl
      }

parsePort :: Maybe String -> Maybe Int
parsePort = (readMaybe =<<)
