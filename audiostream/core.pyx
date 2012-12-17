#cython: embedsignature=True
'''
Audiostream python extension
============================

'''

__all__ = ('AudioStream', 'AudioSample', 'AudioException', )

DEF SDL_INIT_AUDIO = 0x10
DEF MIX_CHANNELS_MAX = 32
DEF AUDIO_S16SYS = 0x8010

from libc.stdlib cimport malloc, free, calloc
from libc.string cimport memset, memcpy
from libc.math cimport sin

include "common.pxi"
include "ringbuffer.pxi"


class AudioException(Exception):
    '''Exception returned by the audiostream module
    '''
    pass


cdef void audio_callback(int chan, void *stream, int l, void *userdata) nogil:
    cdef RingBuffer *rb = <RingBuffer *>userdata
    cdef char *cbuf = rb_read(rb, l)
    if cbuf == NULL:
        return
    memcpy(stream, <void *>cbuf, l)
    free(cbuf)


cdef class AudioSample:
    ''':class:`AudioSample` is a class for writing data on the speaker. The data
    goes first on a RingBuffer, and the buffer is consumed by the speaker,
    according to the :class:`AudioStream` initialization.

    Example::

        stream = AudioStream(channels=1, buffersize=1024, rate=22050)
        sample = AudioSample()
        stream.add_sample(sample)

        sample.play()
        while True:
            # audio stuff, this is not accurate.
            sample.write("\\x00\\x00\\x00\\x00\\xff\\xff\\xff\\xff")

    You must fill the sample as much as possible, in order to prevent buffer
    underflow. If you don't give enough data, the speaker will read '\\x00' data.

    You should use :class:`audiostream.sources.ThreadSource` instead.
    '''

    cdef int channel
    cdef Mix_Chunk *raw_chunk
    cdef AudioStream stream
    cdef public unsigned int index
    cdef RingBuffer* ring

    def __cinit__(self):
        self.channel = -1
        self.raw_chunk = NULL
        self.stream = None
        self.index = 0
        self.ring = rb_new(8192 * 2)

    cdef void dealloc(self):
        if self.raw_chunk != NULL:
            Mix_FreeChunk(self.raw_chunk)
            self.raw_chunk = NULL

    def write(self, bytes chunk):
        '''Write a data chunk into the ring buffer, it will be consumed later by
        the speaker.
        '''
        cdef int lchunk = len(chunk)
        cdef char *cchunk = <char *>chunk
        with nogil:
            rb_write(self.ring, lchunk, cchunk)

    cdef void alloc(self):
        cdef AudioStream stream = self.stream

        self.channel = stream.alloc_channel()
        if self.channel == -1:
            raise AudioException('AudioSample: no more free channel')

        cdef uint8_t *silence = NULL
        cdef uint32_t l = stream.rate * stream.buffersize * stream.channels
        silence = <uint8_t *>calloc(1, l)
        self.raw_chunk = Mix_QuickLoad_RAW(silence, l)
        if self.raw_chunk == NULL:
            raise AudioException('AudioSample: unable to load silence')
        print 'alloc', self.channel

    cdef void registereffect(self) with gil:
        with nogil:
            SDL_LockAudio()
            Mix_RegisterEffect(self.channel, audio_callback, NULL, <void *>self.ring)
            SDL_UnlockAudio()

    def play(self):
        '''Play the sample using the internal ring buffer.
        '''
        cdef int ret
        if self.channel == -1:
            self.alloc()
        self.index = 0
        self.registereffect()
        with nogil:
            ret = Mix_PlayChannel(self.channel, self.raw_chunk, -1)

        if ret == -1:
            print 'error', <bytes>Mix_GetError()

    def stop(self):
        '''Stop the playback.
        '''
        with nogil:
            Mix_HaltChannel(self.channel)


cdef class AudioStream:
    ''':class:`AudioStream` class is the base for initializing the internal
    audio.
    
    .. warning::
    
        You can instanciate only one AudioStream in a process. It must be
        instanciated before any others components of the library.
    '''

    cdef list samples
    cdef int audio_init
    cdef readonly int rate
    cdef readonly int channels
    cdef readonly int buffersize
    cdef int mix_channels_usage[MIX_CHANNELS_MAX]

    def __cinit__(self, *args, **kw):
        self.audio_init = 0

    def __init__(self, rate=44100, channels=2, buffersize=1024):
        self.samples = []
        self.rate = rate
        self.channels = channels
        self.buffersize = buffersize

        if self.init_audio() < 0:
            raise AudioException('AudioStream: unable to initialize audio')


    def add_sample(self, AudioSample sample):
        sample.stream = self
        self.samples.append(sample)

    def remove_sample(self, sample):
        sample.dealloc()
        self.samples.pop(sample, None)


    # private

    cdef int init_audio(self):
        if self.audio_init == 1:
            return 0

        PyEval_InitThreads()

        if SDL_Init(SDL_INIT_AUDIO) < 0:
            print 'SDL_Init: %s' % SDL_GetError()
            return -1

        if Mix_OpenAudio(self.rate, AUDIO_S16SYS, self.channels, self.buffersize):
            print 'Mix_OpenAudio: %s' % SDL_GetError()
            return -1

        memset(self.mix_channels_usage, 0, sizeof(int) * MIX_CHANNELS_MAX)

        SDL_LockAudio()
        print 'AudioStream ask for', self.rate, self.channels
        Mix_QuerySpec(&self.rate, NULL, &self.channels)
        print 'AudioStream got', self.rate, self.channels
        Mix_AllocateChannels(MIX_CHANNELS_MAX)
        SDL_UnlockAudio()

        self.audio_init = 1
        return 0

    cdef int alloc_channel(self):
        cdef int i
        for i in xrange(MIX_CHANNELS_MAX):
           if self.mix_channels_usage[i] == 0:
               self.mix_channels_usage[i] = 1
               return i
        return -1

