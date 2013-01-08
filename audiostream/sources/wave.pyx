__all__ = ('SineSource', )

from libc.math cimport sin
from array import array
from audiostream.sources.thread import ThreadSource

class SineSource(ThreadSource):

    def __init__(self, stream, frequency, *args, **kwargs):
        ThreadSource.__init__(self, stream, *args, **kwargs)
        self._freq = float(frequency)
        self.chunksize = kwargs.get('chunksize', 64)
        self.next_gen_left = self.next_gen_right = None
        self.gen_left = self.sine(frequency=frequency)
        self.gen_right = self.sine(frequency=frequency)

    def __set_freq__(self, float freq):
        self._freq = freq
        self.next_gen_left = self.sine(frequency=freq)
        self.next_gen_right = self.sine(frequency=freq)
    def __get_freq__(self):
        return self._freq
    frequency = property(__get_freq__, __set_freq__)

    def get_bytes(self):
        if self.channels == 1:
            return self._get_bytes_mono()
        elif self.channels == 2:
            return self._get_bytes_stereo()
        assert(0)

    def _get_bytes_mono(self):
        cdef int i = 0
        buf = array('h', '\x00' * self.chunksize)
        lvl = None
        glnext = self.gen_left.next
        next_gen_left = self.next_gen_left
        while i < self.chunksize / 2:
            vl = glnext()
            if next_gen_left and lvl == 0 and vl > 0:
                self.gen_left = self.next_gen_left
                glnext = self.gen_left.next
                self.next_gen_left = next_gen_left = None
                vl = glnext()
            buf[i] = lvl = vl
            i += 1
        return buf.tostring()

    def _get_bytes_stereo(self):
        cdef int i = 0
        buf = array('h', '\x00' * self.chunksize)
        lvl = lvr = None
        glnext = self.gen_left.next
        grnext = self.gen_right.next
        next_gen_left = self.next_gen_left
        next_gen_right = self.next_gen_right
        while i < self.chunksize / 2:
            vl = glnext()
            vr = grnext()
            if next_gen_left and lvl == 0 and vl > 0:
                self.gen_left = self.next_gen_left
                glnext = self.gen_left.next
                self.next_gen_left = next_gen_left = None
                vl = glnext()
            if next_gen_right and lvr == 0 and vr > 0:
                self.gen_right = self.next_gen_right
                grnext = self.gen_right.next
                self.next_gen_right = next_gen_right = None
                vr = grnext()
            buf[i] = lvl = vl
            buf[i+1] = lvr = vr
            i += 2
        return buf.tostring()

    def sine(self, float frequency=440.0, float amplitude=0.5):
        cdef int i = 0
        cdef float sincomp
        cdef list lookup_table
        cdef float pi = 3.141592653589793
        cdef float f = 65535 / pi
        cdef float pi2 = 2.0 * pi
        cdef float af = f * amplitude
        cdef float pi2freq = pi2 * frequency
        cdef int period = int(self.rate / frequency)
        amplitude = max(0.0, min(1.0, amplitude))
        lookup_table = []
        try:
            while i < period:
                sincomp = sin(pi2freq *(float(i%period)/float(self.rate)))
                yield <short>(af * sincomp)
                i += 1
                if i >= period:
                    i = 0
        except StopIteration:
            return


