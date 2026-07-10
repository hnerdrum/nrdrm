{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Support.TestDb
  ( TestEnv (..),
    withTestDb,
    testDatabaseUrl,
    resetTestData,
    truncateTable,
  )
where

import Configuration.Dotenv (Config (..), defaultConfig, loadFile)
import Control.Applicative ((<|>))
import Control.Exception (IOException, SomeException, catch, displayException, try)
import Control.Monad (filterM, void)
import Data.Pool (Pool, destroyAllResources, withResource)
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Database.Connection (createConnection)
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple.Types (Query (..))
import qualified Database.PostgreSQL.Simple as PG
import ORM.Core (Entity (..))
import Schema.Shelf (BookTable, ShelfTable)
import Schema.Widget (WidgetTable)
import Support.TestMigrations (runTestMigrations)
import System.Directory (doesFileExist)
import System.Environment (lookupEnv)
import Test.Hspec (Spec, SpecWith, afterAll, beforeAll, beforeWith)

newtype TestEnv = TestEnv
  { envPool :: Pool Connection
  }

withTestDb :: SpecWith TestEnv -> Spec
withTestDb spec =
  beforeAll setupTestEnv $
    afterAll destroyTestEnv $
      beforeWith (\env -> resetTestData env >> return env) spec

testDatabaseUrl :: IO String
testDatabaseUrl = do
  loadTestEnv
  mTestUrl <- lookupEnv "TEST_DATABASE_URL"
  mDbUrl <- lookupEnv "DATABASE_URL"
  case mTestUrl <|> mDbUrl of
    Nothing ->
      fail $
        unlines
          [ "No test database URL configured.",
            "Set TEST_DATABASE_URL (recommended) or DATABASE_URL.",
            "Copy .env.test.example to .env.test, or run: make test"
          ]
    Just url -> return url

setupTestEnv :: IO TestEnv
setupTestEnv = do
  databaseUrl <- testDatabaseUrl
  result <- try @SomeException $ do
    runTestMigrations databaseUrl
    createConnection databaseUrl
  case result of
    Left err -> fail (connectionErrorMessage databaseUrl err)
    Right pool -> return TestEnv {envPool = pool}

connectionErrorMessage :: String -> SomeException -> String
connectionErrorMessage databaseUrl err =
  unlines
    [ "Could not connect to the test database.",
      displayException err,
      "",
      "URL: " <> databaseUrl,
      "",
      "Start the test database with:",
      "  make test-db-up",
      "",
      "Or run migrations + tests together:",
      "  make test"
    ]

destroyTestEnv :: TestEnv -> IO ()
destroyTestEnv TestEnv {envPool = pool} =
  destroyAllResources pool

resetTestData :: TestEnv -> IO ()
resetTestData env = do
  truncateTable @WidgetTable env
  truncateTable @BookTable env
  truncateTable @ShelfTable env

truncateTable ::
  forall table.
  (Entity table) =>
  TestEnv ->
  IO ()
truncateTable TestEnv {envPool = pool} =
  withResource pool $ \conn ->
    void $
      PG.execute_
        conn
        (Query (TE.encodeUtf8 ("TRUNCATE " <> tableName @table <> " RESTART IDENTITY CASCADE" :: Text)))

loadTestEnv :: IO ()
loadTestEnv = do
  paths <- filterM doesFileExist [".env.test", ".env"]
  case paths of
    [] -> return ()
    envPaths ->
      catch
        (loadFile defaultConfig {configPath = envPaths})
        (const (return ()) :: IOException -> IO ())
