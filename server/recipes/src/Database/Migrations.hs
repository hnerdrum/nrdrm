module Database.Migrations
    (
      runDbMigrations
    ) where

import Database.PostgreSQL.Simple
    ( Connection, connectPostgreSQL, withTransaction )
import Database.PostgreSQL.Simple.Migration.V1Compat
    ( MigrationResult,
      MigrationCommand(MigrationDirectory, MigrationInitialization),
      runMigration,
      MigrationContext(MigrationContext) )
import qualified Data.ByteString.Char8 as B8

initializeMigrations :: Connection -> IO (MigrationResult String)
initializeMigrations conn = runMigration $ MigrationContext MigrationInitialization True conn

runDbMigrations :: String -> IO ()
runDbMigrations databaseUrl = do
  let dir = "migrations"
  conn <- connectPostgreSQL $ B8.pack databaseUrl
  withTransaction conn $ do
    _ <- initializeMigrations conn
    _ <- runMigration $ MigrationContext (MigrationDirectory dir) True conn
    return ()
