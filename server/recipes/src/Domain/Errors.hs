module Domain.Errors
  ( AppError (..),
    DomainError (..),
    addErrorContext,
  )
where

import Data.Aeson
import Data.Text

data AppError = AppError
  { error :: DomainError,
    message :: Text,
    context :: Value
  }

data DomainError = NotFoundError | MultipleEntitiesError | WrongPwdError

addErrorContext :: Value -> Either AppError a -> Either AppError a
addErrorContext context (Left appError) = Left appError {context = context}
addErrorContext _ (Right a) = Right a
