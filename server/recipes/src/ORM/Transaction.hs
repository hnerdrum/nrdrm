module ORM.Transaction
  ( transaction,
  )
where

import Data.Pool (Pool, withResource)
import Database.PostgreSQL.Simple (Connection, withTransaction)

transaction :: Pool Connection -> (Connection -> IO a) -> IO a
transaction pool action =
  withResource pool $ \conn -> withTransaction conn (action conn)
