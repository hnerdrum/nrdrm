module Domain.Errors
  ( DomainError (..),
  )
where

import Data.Text

data DomainError = NotFoundError Text | MultipleEntitiesError Text | WrongPwdError Text
