import sys
from time import sleep
import librosa
import numpy as np
from audiostream import get_output
from audiostream.sources.thread import ThreadSource


class MonoAmplitudeSource(ThreadSource):
    """A data source for float32 mono binary data, as loaded by libROSA/soundfile."""
    def __init__(self, stream, data, *args, **kwargs):
        super().__init__(stream, *args, **kwargs)
        self.chunksize = kwargs.get('chunksize', 64)
        self.data = data
        self.cursor = 0

    def get_bytes(self):
        chunk = self.data[self.cursor:self.cursor+self.chunksize]
        self.cursor += self.chunksize

        if not isinstance(chunk, np.ndarray):
            chunk = np.array(chunk)
        assert len(chunk.shape) == 1 and chunk.dtype == np.dtype('float32')

        # Convert to 16 bit format.
        return (chunk * 2**15).astype('int16').tobytes()


# For example purposes, load first 30 seconds only.
# Data must be mono.
data, sr = librosa.core.load(sys.argv[1], mono=True, sr=None, duration=30)

stream = get_output(channels=1, rate=sr, buffersize=1024)
source = MonoAmplitudeSource(stream, data)
source.start()

# Wait until playback has finished.
while source.cursor < len(data):
    sleep(.5)

source.stop()
