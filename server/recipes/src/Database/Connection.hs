module Database.Connection
  ( createConnection,
  )
where

import qualified Data.ByteString.Char8 as B8
import Data.Pool (Pool, defaultPoolConfig, newPool)
import qualified Database.PostgreSQL.Simple as PG

createConnection :: String -> IO (Pool PG.Connection)
createConnection databaseUrl =
  newPool
    ( defaultPoolConfig
        (PG.connectPostgreSQL $ B8.pack databaseUrl)
        PG.close
        10 -- Number of seconds per stripe
        10 -- Maximum number of connections
    )