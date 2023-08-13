module Database.Connection
    (
      createConnection
    ) where

import qualified Database.PostgreSQL.Simple as PG
import Data.Pool (Pool, createPool)

localPG :: PG.ConnectInfo
localPG = PG.defaultConnectInfo
        { PG.connectHost = "localhost"
        , PG.connectDatabase = "nrdrm"
        , PG.connectUser = "nrdrm"
        , PG.connectPassword = "nrdrm"
        }

createConnection :: IO (Pool PG.Connection)
createConnection = do
    createPool
        (PG.connect localPG)
        PG.close
        1 -- Number of stripes
        10 -- Number of seconds per stripe
        5 -- Maximum number of connections