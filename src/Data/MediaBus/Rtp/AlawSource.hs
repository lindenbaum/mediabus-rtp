module Data.MediaBus.Rtp.AlawSource
  ( rtpAlaw16kHzS16Source
  ) where

import Conduit
import qualified Data.ByteString as B
import Data.MediaBus
import Data.MediaBus.Rtp.Packet
import Data.MediaBus.Rtp.Source
import Data.Proxy
import Data.Streaming.Network (HostPreference)
import Data.Word
import Network.Socket (SockAddr)

rtpAlaw16kHzS16Source
  :: MonadResource m
  => Int
  -> HostPreference
  -> Int
  -> Source m (Stream RtpSsrc RtpSeqNum (Ticks (Hz 16000) Word64) () (Segment (640 :/ Hz 16000) (Audio (Hz 16000) Mono (Raw S16))))
rtpAlaw16kHzS16Source !udpListenPort !udpListenIP !reorderBufferSize =
  annotateTypeSource
    (Proxy :: Proxy (Stream (SourceId (Maybe SockAddr)) RtpSeqNum (ClockTimeDiff UtcClock) () B.ByteString))
    (udpDatagramSource useUtcClock udpListenPort udpListenIP) .|
  rtpSource .|
  rtpPayloadDemux [(8, alawPayloadHandler)] mempty .|
  annotateTypeCOut
    (Proxy :: Proxy (Stream RtpSsrc RtpSeqNum (Ticks (Hz 8000) Word32)  () (Audio (Hz 8000) Mono (Raw S16))))
    alawToS16 .|
  resample8to16kHz' (0 :: Pcm Mono S16) .|
  convertTicksC' (Proxy :: Proxy '(Hz 8000, Word32)) (Proxy :: Proxy '(Hz 16000, Word64))  .|
  reorderFramesBySeqNumC reorderBufferSize .|
  segmentC
