module ORM.ErrorsSpec
  ( errorsSpec,
  )
where

import Database.PostgreSQL.Simple.Internal (SqlError (..))
import ORM.Errors (ORMError (..))
import ORM.Sql (fromSqlError)
import Test.Hspec (Spec, describe, it, shouldBe)

errorsSpec :: Spec
errorsSpec =
  describe "ORM.Sql.fromSqlError" $ do
    it "maps unique violations to UniqueViolation" $ do
      fromSqlError sampleUniqueError
        `shouldBe` UniqueViolation "duplicate key value violates unique constraint"

    it "maps other sql errors to DatabaseError" $ do
      fromSqlError sampleOtherError
        `shouldBe` DatabaseError "connection failure"

sampleUniqueError :: SqlError
sampleUniqueError =
  SqlError
    { sqlState = "23505",
      sqlErrorMsg = "duplicate key value violates unique constraint",
      sqlErrorDetail = "",
      sqlErrorHint = ""
    }

sampleOtherError :: SqlError
sampleOtherError =
  SqlError
    { sqlState = "08006",
      sqlErrorMsg = "connection failure",
      sqlErrorDetail = "",
      sqlErrorHint = ""
    }
