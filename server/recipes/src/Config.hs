module Config
    (
      AppConfig(..)
    , loadConfig  
    ) where

import System.Environment (lookupEnv)
import Control.Monad (join)
import Configuration.Dotenv (loadFile, defaultConfig)
import Data.List.Split (splitOn)
import Data.Maybe (fromMaybe)
import Text.Read (readMaybe)

data AppConfig = AppConfig
  { port :: Int
  , databaseUrl :: String
  , allowedOrigins :: [String]
  } deriving (Show)

loadEnv :: IO ()
loadEnv = loadFile defaultConfig

loadConfig :: IO AppConfig
loadConfig = do
  loadEnv
  loadedPort <- lookupEnv "PORT"
  loadedDbUrl <- lookupEnv "DATABASE_URL"
  loadedAllowedOrigins <- lookupEnv "ALLOWED_ORIGINS"
  return $ AppConfig
    { port = fromMaybe 8000 $ parsePort loadedPort
    , databaseUrl = fromMaybe "" loadedDbUrl
    , allowedOrigins = parseAllowedOrigins loadedAllowedOrigins
    }

parsePort :: Maybe String -> Maybe Int
parsePort = join . fmap readMaybe

parseAllowedOrigins :: Maybe String -> [String]
parseAllowedOrigins Nothing = []
parseAllowedOrigins (Just origin) = splitOn "," origin