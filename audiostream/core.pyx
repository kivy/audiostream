#cython: embedsignature=True
'''
Audiostream python extension
============================

'''

__all__ = (
    'get_output',
    'get_input',
    'get_input_sources',
    'AudioOutput',
    'AudioInput',
    'AudioSample',
    'AudioException')

DEF SDL_INIT_AUDIO = 0x10
DEF MIX_CHANNELS_MAX = 32
DEF AUDIO_S16SYS = 0x8010
DEF AUDIO_S8 = 0x8008

from libc.stdlib cimport malloc, free, calloc
from libc.string cimport memset, memcpy
from libc.math cimport sin
#from time import time

include "config.pxi"
include "common.pxi"
include "ringbuffer.pxi"


class AudioException(Exception):
    '''Exception returned by the audiostream module
    '''
    pass


cdef void audio_callback(int chan, void *stream, int l, void *userdata) nogil:
    cdef RingBuffer *rb = <RingBuffer *>userdata
    cdef int datasize

    datasize = rb_read_into(rb, l, <char *>stream)
    if datasize < 0:
        memset(stream, 0, l)


cdef class AudioSample:
    cdef int channel
    cdef Mix_Chunk *raw_chunk
    cdef AudioOutput stream
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
        cdef int lchunk = len(chunk)
        cdef char *cchunk = <char *>chunk
        with nogil:
            rb_write(self.ring, lchunk, cchunk)

    cdef void alloc(self):
        cdef AudioOutput stream = self.stream

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

cdef class AudioOutput:
    ''':class:`AudioOutput` class is the base for initializing the internal
    audio.

    .. warning::

        You can instanciate only one AudioOutput in a process. It must be
        instanciated before any others components of the library.
    '''

    cdef list samples
    cdef int audio_init
    cdef readonly int rate
    cdef readonly int channels
    cdef readonly int buffersize
    cdef readonly int encoding
    cdef int mix_channels_usage[MIX_CHANNELS_MAX]

    def __cinit__(self, *args, **kw):
        self.audio_init = 0

    def __init__(self, rate=44100, channels=2, buffersize=1024, encoding=16):
        self.samples = []
        self.rate = rate
        self.channels = channels
        self.buffersize = buffersize
        self.encoding = encoding

        assert(encoding in (8, 16))
        assert(channels >= 1)
        assert(buffersize >= 0)

        if self.init_audio() < 0:
            raise AudioException('AudioOutput: unable to initialize audio')


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

        cdef unsigned int encoding = AUDIO_S8 if self.encoding == 8 else AUDIO_S16SYS
        if Mix_OpenAudio(self.rate, encoding, self.channels, self.buffersize):
            print 'Mix_OpenAudio: %s' % SDL_GetError()
            return -1

        memset(self.mix_channels_usage, 0, sizeof(int) * MIX_CHANNELS_MAX)

        SDL_LockAudio()
        print 'AudioOutput ask for', self.rate, self.channels
        Mix_QuerySpec(&self.rate, NULL, &self.channels)
        print 'AudioOutput got', self.rate, self.channels
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


class AudioInput(object):
    '''Abstract class for handling an audio input. Normally, the default audio
    source is the microphone. It will be recorded with a rate of 44100hz, mono,
    with 16bit PCM. Theses defaults are the most used and guaranted to work on
    Android and iOS. Any others combination might fail.

    .. warning::
        Don't use this class directly, use :func:`AudioOutput.get_input`.

    '''
    def __init__(self, callback=None, source='default', rate=44100, channels=1,
            buffersize=-1, encoding=16):
        super(AudioInput, self).__init__()
        if encoding not in (8, 16):
            raise Exception('Invalid encoding, must be one of 8, 16')
        if channels not in (1, 2):
            raise Exception('Invalid channels, must be one of 1, 2')
        self.callback = callback
        self.source = source
        self.rate = rate
        self.channels = channels
        self.buffersize = buffersize
        self.encoding = encoding

    def start(self):
        '''Start the input to gather data from the source.
        '''
        pass

    def stop(self):
        '''Stop the input to gather data from the source.
        '''
        pass

    def poll(self):
        '''Call it regulary to read the input stream.
        '''
        return False


def get_input(**kwargs):
    IF PLATFORM == 'android':
        from audiostream.platform.plat_android import AndroidAudioInput
        return AndroidAudioInput(**kwargs)
    ELIF PLATFORM == 'ios':
        from audiostream.platform.plat_ios import IosAudioInput
        return IosAudioInput(**kwargs)
    ELIF PLATFORM == 'darwin':
        from audiostream.platform.plat_mac import MacAudioInput
        return MacAudioInput(**kwargs)
    ELSE:
        raise Exception('Unsupported platform')


def get_input_sources():
    IF PLATFORM == 'android':
        return ('camcorder', 'default', 'mic', 'voice_call',
                'voice_communication', 'voice_downlink', 'voice_recognition',
                'voice_uplink')
    ELIF PLATFORM == 'ios':
        return ('default', )
    ELIF PLATFORM == 'mac':
        return ('default', )
    ELSE:
        raise Exception('Unsupported platform')


def get_output(**kwargs):
    return AudioOutput(**kwargs)
