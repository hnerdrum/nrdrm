module Database.Connection
    (
      createConnection
    ) where

import qualified Database.PostgreSQL.Simple as PG
import qualified Data.ByteString.Char8 as B8
import Data.Pool (Pool, createPool)

createConnection :: String ->  IO (Pool PG.Connection)
createConnection dbUrl = do
  createPool
          (PG.connectPostgreSQL $ B8.pack dbUrl)
          PG.close
          1 -- Number of stripes
          10 -- Number of seconds per stripe
          5 -- Maximum number of connections
