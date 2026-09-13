module Support.TestMigrations
  ( runTestMigrations,
  )
where

import qualified Data.ByteString.Char8 as B8
import Database.PostgreSQL.Simple
  ( Connection,
    connectPostgreSQL,
    withTransaction,
  )
import Database.PostgreSQL.Simple.Migration.V1Compat
  ( MigrationCommand (MigrationDirectory, MigrationInitialization),
    MigrationContext (MigrationContext),
    MigrationResult,
    runMigration,
  )

testMigrationsDir :: FilePath
testMigrationsDir = "test/migrations"

initializeMigrations :: Connection -> IO (MigrationResult String)
initializeMigrations conn = runMigration $ MigrationContext MigrationInitialization True conn

runTestMigrations :: String -> IO ()
runTestMigrations databaseUrl = do
  conn <- connectPostgreSQL $ B8.pack databaseUrl
  withTransaction conn $ do
    _ <- initializeMigrations conn
    _ <- runMigration $ MigrationContext (MigrationDirectory testMigrationsDir) True conn
    return ()
