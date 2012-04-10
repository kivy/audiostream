'''
Audiostream python extension
============================

::

    from audiostream import AudioStream, AudioSample

    def sin_callback(...):
        buffer = [...]
        return buffer

    stream = AudioStream(channels=2)

    # start the audio theard
    stream.start()

    # add a new sample to be played
    sin_sample = AudioSample(sin_callback)
    stream.add_sample(sin_sample)

    # later, stop the stream
    stream.stop()

'''

from libc.stdlib cimport malloc, free
from libc.string cimport memset, memcpy


cdef class AudioSample:

    cdef object audio_callback

    def __init__(self, audio_callback):
        self.audio_callback = audio_callback


cdef class AudioStream:

    cdef list samples

    def __init__(self, rate=44100, channels=2, buffersize=1024):
        self.samples = []

    def add_sample(self, sample):
        self.samples.append(sample)

    def remove_sample(self, sample):
        self.samples.pop(sample, None)

    def clear_samples(self):
        self.samples = []
