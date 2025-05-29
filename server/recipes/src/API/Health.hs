{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

{-# HLINT ignore "Redundant <$>" #-}

module API.Health
  ( healthHandler,
  )
where

import App (AppContext (..), AppM)
import Control.Monad.Reader (asks)
import Domain.Health (HealthCheck (..))

healthHandler :: AppM HealthCheck
healthHandler = HealthCheck <$> asks bootTime <*> asks apiVersion
