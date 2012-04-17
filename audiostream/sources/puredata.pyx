from libc.math cimport sin

import array

from audiostream.sources.thread import ThreadSource
from pylibpd import PdManager, libpd_open_patch, libpd_blocksize

class PatchSource(ThreadSource):

    def __init__(self, patchfile, *args, **kwargs):
        ThreadSource.__init__(self, *args, **kwargs)
        self.patch = patchfile
        self.pd_gen = self.pd_wave(patchfile,
                                   self.channels,
                                   self.samplerate,
                                   self.bufsize)

    def get_bytes(self):
        return self.pd_gen.next()

    def pd_wave(char* patch, int channels, int samplerate, int buffersize):
        cdef int blocksize, i
        m = PdManager(1, channels, samplerate, 1)
        patchfile = libpd_open_patch(patch, '.')
        blocksize = libpd_blocksize()
        print "*"*20, 'libpd reports %d blocksize' % blocksize
        blocksize = blocksize * channels
        print "*"*20, 'real %d blocksize' % blocksize
        inbuf = array.array('h', '\x00' * blocksize)
        try:
            i = 0
            while 1:
                buf = array.array('h', '\x00' * buffersize)
                for x in range(buffersize / 2):
                    if x % blocksize == 0:
                        outbuf = m.process(inbuf)
                    buf[x] = outbuf[(x % blocksize)]
                yield buf.tostring()
        except StopIteration:
            return

