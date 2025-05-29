module Domain.Health
  ( HealthCheck (..),
  )
where

import Data.Aeson.TH (defaultOptions, deriveJSON)
import Data.Text (Text)

data HealthCheck = HealthCheck
  { boot_time :: Text,
    api_version :: Text
  }
  deriving (Show)

$(deriveJSON defaultOptions ''HealthCheck)
