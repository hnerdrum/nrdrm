{-# LANGUAGE OverloadedStrings #-}

module Config
    (
      AppConfig(..)
    , loadConfig  
    ) where

import System.Environment (lookupEnv)
import Configuration.Dotenv (loadFile, defaultConfig)
import Data.List.Split (splitOn)
import Data.Maybe (fromMaybe)

data AppConfig = AppConfig
  { databaseUrl :: String
  , allowedOrigins :: [String]
  } deriving (Show)

loadEnv :: IO ()
loadEnv = loadFile defaultConfig

loadConfig :: IO AppConfig
loadConfig = do
  loadEnv
  loadedDbUrl <- lookupEnv "DATABASE_URL"
  loadedAllowedOrigins <- lookupEnv "ALLOWED_ORIGINS"
  return $ AppConfig
    { databaseUrl = fromMaybe "" loadedDbUrl
    , allowedOrigins = parseAllowedOrigins loadedAllowedOrigins
    }

parseAllowedOrigins :: Maybe String -> [String]
parseAllowedOrigins Nothing = []
parseAllowedOrigins (Just origin) = splitOn "," origin