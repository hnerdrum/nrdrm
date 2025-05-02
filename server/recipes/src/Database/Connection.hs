module Database.Connection
  ( createConnection,
  )
where

import qualified Data.ByteString.Char8 as B8
import Data.Pool (Pool, defaultPoolConfig, newPool, setNumStripes)
import qualified Database.PostgreSQL.Simple as PG

createConnection :: String -> IO (Pool PG.Connection)
createConnection databaseUrl = do
  let numStripes = 4
      keepOpenTime = 10 -- seconds
      maxResourcesPerStripe = 5 -- 20 total connections across 4 stripes
      totalMaxConnections = numStripes * maxResourcesPerStripe

      poolConfig =
        setNumStripes (Just numStripes) $
          defaultPoolConfig
            (PG.connectPostgreSQL $ B8.pack databaseUrl)
            PG.close
            keepOpenTime
            totalMaxConnections

  newPool poolConfig