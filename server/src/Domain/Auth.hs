{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Domain.Auth
(
  generateToken
) where

import Crypto.Hash (Digest, SHA256, hash)
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8 as BS
import Domain.User (User(..))

type Token = String

generateToken :: User -> IO Token
generateToken user = do
    let input = BS.concat [userIdBytes, emailBytes]
        hashedBytes :: Digest SHA256
        hashedBytes = hash input
        encodedToken = B64.encode (BS.pack (show hashedBytes))
    return $ BS.unpack encodedToken
  where
    userIdBytes = BS.pack $ show user.id
    emailBytes = BS.pack $ show user.email
