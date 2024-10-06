module Domain.Errors
  ( AppError (..),
    DomainError (..),
    addErrorContext,
  )
where

import Data.Aeson (Object, Value (..))
import qualified Data.Aeson.KeyMap as KM
import Data.Text

data AppError = AppError
  { error :: DomainError,
    message :: Text,
    context :: Value
  }

data DomainError = NotFoundError | MultipleEntitiesError | WrongPwdError

addErrorContext :: Value -> Either AppError a -> Either AppError a
addErrorContext newContext (Left appError) =
  Left appError {context = mergeValues appError.context newContext}
addErrorContext _ (Right a) = Right a

mergeObjects :: Object -> Object -> Object
mergeObjects = KM.unionWith mergeValues

mergeValues :: Value -> Value -> Value
mergeValues (Object o1) (Object o2) = Object (mergeObjects o1 o2)
mergeValues _ v = v
