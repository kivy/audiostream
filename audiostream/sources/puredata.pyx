from libc.math cimport sin

import array

from audiostream.sources.thread import ThreadSource
from pylibpd import PdManager, libpd_open_patch, libpd_blocksize

class PatchSource(ThreadSource):
    def __init__(self, stream, patchfile, *args, **kwargs):
        ThreadSource.__init__(self, stream, *args, **kwargs)
        self.patch = patchfile
        self.pd_gen = self.pd_wave(patchfile)

    def get_bytes(self):
        return next(self.pd_gen)

    def pd_wave(self, patch):
        cdef int blocksize, i
        m = PdManager(1, self.channels, self.rate, 1)
        patchfile = libpd_open_patch(patch, '.')
        blocksize = libpd_blocksize()
        blocksize = blocksize * self.channels
        inbuf = array.array('h', b'\x00' * blocksize)
        try:
            i = 0
            while 1:
                buf = array.array('h', b'\x00' * self.buffersize)
                for x in range(int(self.buffersize / 2)):
                    if x % blocksize == 0:
                        outbuf = m.process(inbuf)
                    buf[x] = outbuf[(x % blocksize)]
                yield buf.tostring()
        except StopIteration:
            return

