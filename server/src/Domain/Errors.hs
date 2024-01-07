{-# LANGUAGE OverloadedStrings #-}

module Domain.Errors
    (
      RecipeError(..)
    , IngredientError(..)
    , UserError(..)
    ) where

import API.Errors (ToServantError (toServerError))
import Servant

data RecipeError = RecipeNotFound | MultipleRecipesFound
  deriving (Eq, Show)

instance ToServantError RecipeError where
  toServerError RecipeNotFound       = err404 { errBody = "Recipe could not be found" }
  toServerError MultipleRecipesFound = err409 { errBody = "Found multiple recipes with matching ID"}

data IngredientError = IngredientNotFound | MultipleIngredientsFound
  deriving (Eq, Show)

instance ToServantError IngredientError where
  toServerError IngredientNotFound = err404 { errBody = "Ingredient could not be found" }
  toServerError MultipleIngredientsFound = err409 { errBody = "Found multiple ingredients with matching ID"}

data UserError = WrongPasswordError | UserNotFound | MultipleUsersFound
  deriving (Eq, Show)

instance ToServantError UserError where
  toServerError UserNotFound = err404 { errBody = "User could not be found" }
  toServerError MultipleUsersFound = err409 { errBody = "Found multiple users with matching email"}
  toServerError WrongPasswordError = err401 { errBody = "Wrong password" }