module Test.Main where

import Prelude

import Control.Coroutine (Consumer, await, consumer, runProcess, ($$), ($~))
import Control.Monad.Aff (Aff, launchAff)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Rec.Class (forever)
import Control.Monad.Trans.Class (lift)
import Data.Argonaut (_Number, _Object, _String, jsonParser)
import Data.Array (init, zipWith)
import Data.Either (Either(..), either)
import Data.Lens ((^?))
import Data.Lens.Index (ix)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Traversable (sequence, sequence_, traverse, traverse_)
import Global.Unsafe (unsafeStringify)
import IPFS (IPFSEff)
import IPFS as IPFS
import IPFS.Files (IPFSObject)
import IPFS.Files as Files
import IPFS.Types (IPFSPath(..))
import Node.Buffer (fromString)
import Node.Buffer as Buffer
import Node.Encoding (Encoding(..))
import Node.Stream as Stream
import Unsafe.Coerce (unsafeCoerce)


pathStr = "/ipfs/QmVLDAhCY3X9P2uRudKAryuQFPM5zqA3Yij1dY8FpGbL7T/quick-start"
path = IPFSPathString pathStr


main :: Eff _ Unit
main = do
  ipfs <- IPFS.connect "localhost" 5001
  _ <- launchAff $ do
    ver <- IPFS.version ipfs
    ident <- IPFS.identity ipfs

    let strFile f = liftEff $ Stream.onData f \bfr -> do
          log "reading file"
          log =<< Buffer.toString UTF8 bfr

        endFile f = liftEff $ Stream.onEnd f $ log "end file"


    liftEff $ log "----- Read existing file -----"
    stream <- Files.cat ipfs path
    strFile stream
    endFile stream


    liftEff $ log "----- Write file -----"
    buffers <- traverse (\x -> liftEff $ Buffer.fromString x UTF8)
                ["this is a test file", "another test file"]
    let paths = ["/tmp/testfile.txt", "/tmp/testfile2.txt"]
    results <- Files.add ipfs (zipWith (\path content -> {path, content}) paths buffers)

    -- removing the last result path since it's the /tmp/ directory
    let hashes = map (IPFSPathString <<< _.hash) $ fromMaybe [] (init results)

    liftEff $ log "----- Read new file ----"
    traverse_ (strFile <=< Files.cat ipfs) hashes


    liftEff $ log "----- write JSON file -----"
    jsonObj <- liftEff $ Buffer.fromString """
        {"test": "hello!!",
        "other": 1.0}
          """ UTF8

    results <- Files.add ipfs [{path: "/tmp/jsontest.txt", content: jsonObj }]
    let hashes = map (IPFSPathString <<< _.hash) $ fromMaybe [] (init results)

    liftEff $ log "----- Producer with cat -----"
    prd <- traverse (Files.catProducer ipfs) hashes
    let cns :: Consumer String (Aff _) Unit
        cns = consumer \str -> do
          let obj = either id id do
                json <- jsonParser str
                test <- maybe (Left "No 'test' field") Right $
                          json ^? _Object <<< ix "test" <<< _String
                other <- maybe (Left "No 'other' field") Right $
                          json ^? _Object <<< ix "other" <<< _Number
                pure $ "test: " <> test <> "\nother: " <> show other

          liftEff $ log "consuming"
          liftEff $ log obj
          pure Nothing

    traverse_ (\p -> runProcess (p $$ cns)) prd

    liftEff $ do
      log $ "version: " <> ver.version
      log $ "id: " <> ident.id

  pure unit
