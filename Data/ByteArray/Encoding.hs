-- |
-- Module      : Data.ByteArray.Encoding
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : unknown
--
-- ByteArray base converting
--
module Data.ByteArray.Encoding
    ( convertToBase
    , convertFromBase
    , Base(..)
    ) where

import           Data.ByteArray.Types
import qualified Data.ByteArray.Types        as B
import qualified Data.ByteArray.Methods      as B
import           Data.Memory.Internal.Compat
import           Data.Memory.Encoding.Base16
import           Data.Memory.Encoding.Base64

-- | Different bases that can be used
data Base = Base16 -- ^ similar to hexadecimal
          | Base64
          deriving (Show,Eq)

-- | Convert a bytearray to the equivalent representation in a specific Base
convertToBase :: (ByteArrayAccess bin, ByteArray bout) => Base -> bin -> bout
convertToBase Base16 b =
    B.unsafeCreate (B.length b * 2) $ \bout ->
    B.withByteArray b               $ \bin  ->
        toHexadecimal bout bin (B.length b)
convertToBase Base64 b =
    B.unsafeCreate outLen $ \bout ->
    withByteArray b       $ \bin  ->
        toBase64 bout bin (B.length b)
  where (q,r)  = B.length b `divMod` 3
        outLen = 4 * (if r == 0 then q else q+1)

-- | Try to Convert a bytearray from the equivalent representation in a specific Base
convertFromBase :: (ByteArrayAccess bin, ByteArray bout) => Base -> bin -> Either String bout
convertFromBase Base16 b
    | odd (B.length b) = Left "base16: input: invalid length"
    | otherwise        = unsafeDoIO $ do
        (ret, out) <-
            B.allocRet (B.length b `div` 2) $ \bout ->
            B.withByteArray b               $ \bin  ->
                fromHexadecimal bout bin (B.length b)
        case ret of
            Nothing  -> return $ Right out
            Just ofs -> return $ Left ("base16: input: invalid encoding at offset: " ++ show ofs)
convertFromBase Base64 b = unsafeDoIO $
    withByteArray b $ \bin -> do
        mDstLen <- unBase64Length bin (B.length b)
        case mDstLen of
            Nothing     -> return $ Left "base64: input: invalid length"
            Just dstLen -> do
                (ret, out) <- B.allocRet dstLen $ \bout -> fromBase64 bout bin (B.length b)
                case ret of
                    Nothing  -> return $ Right out
                    Just ofs -> return $ Left ("base64: input: invalid encoding at offset: " ++ show ofs)
