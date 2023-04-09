{-# LANGUAGE OverloadedStrings #-}

module Gateway where

import Web.Scotty

gateway :: IO ()
gateway =
  scotty 3000 $
    get "/" $
      text "Gateway"
