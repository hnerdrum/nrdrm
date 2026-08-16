module ORM.Db
  ( Db (..),
    runDb,
    withTransaction,
    liftIO,
  )
where

import Control.Monad.IO.Class (MonadIO (..), liftIO)
import Data.Pool (Pool, withResource)
import Database.PostgreSQL.Simple (Connection)
import qualified Database.PostgreSQL.Simple as PG

newtype Db a = Db {unDb :: Connection -> IO a}

instance Functor Db where
  fmap f (Db g) = Db (fmap f . g)

instance Applicative Db where
  pure x = Db (const (pure x))
  Db f <*> Db x = Db $ \conn -> f conn <*> x conn

instance Monad Db where
  Db m >>= f = Db $ \conn -> do
    a <- m conn
    unDb (f a) conn

instance MonadIO Db where
  liftIO io = Db (const io)

runDb :: Pool Connection -> Db a -> IO a
runDb pool (Db action) = withResource pool action

withTransaction :: Pool Connection -> Db a -> IO a
withTransaction pool (Db action) =
  withResource pool $ \conn -> PG.withTransaction conn (action conn)
