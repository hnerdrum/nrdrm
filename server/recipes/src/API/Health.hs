{-# LANGUAGE OverloadedStrings #-}


module API.Health
  (
    healthHandler
  ) where

import App (AppM)
import Data.Text

healthHandler :: AppM Text
healthHandler = return "OK"