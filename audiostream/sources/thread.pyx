import cython, array
from threading import Thread

from audiostream.core import AudioSample

class ThreadSource(Thread):
    def __init__(self, stream):
        Thread.__init__(self)
        self.daemon = True
        self.buffersize = stream.buffersize
        self.channels = stream.channels
        self.rate = stream.rate
        self.sample = AudioSample()
        stream.add_sample(self.sample)

    def get_bytes(self):
        return ''

    def run(self):
        self.sample.play()
        while True:
            self.sample.write(self.get_bytes())

    def stop(self):
        self.sample.stop()

