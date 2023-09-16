{-# LANGUAGE OverloadedStrings #-}

module Domain.Errors
    (
      RecipeError(..)
    ) where

import API.Errors (ToServantError (toServerError))
import Servant

data RecipeError = RecipeNotFound | MultipleRecipesFound
  deriving (Eq, Show)

instance ToServantError RecipeError where
  toServerError RecipeNotFound       = err404 { errBody = "Recipe could not be found" }
  toServerError MultipleRecipesFound = err409 { errBody = "Found multiple recipes with matching ID"}