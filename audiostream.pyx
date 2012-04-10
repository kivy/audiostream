'''
Audiostream python extension
============================

'''

DEF SDL_INIT_AUDIO = 0x10
DEF MIX_CHANNELS_MAX = 32
DEF AUDIO_S16SYS = 0x8010

import cython
from libc.stdlib cimport malloc, free, calloc
from libc.string cimport memset, memcpy

ctypedef signed long long int64_t
ctypedef unsigned long long uint64_t
ctypedef unsigned char uint8_t
ctypedef unsigned int uint32_t
ctypedef short int16_t
ctypedef unsigned short uint16_t

cdef extern from "Python.h":
    void PyEval_InitThreads()

cdef extern from "SDL.h" nogil:
    struct SDL_AudioSpec:
        int freq
        uint16_t format
        uint8_t channels
        uint8_t silence
        uint16_t samples
        uint16_t padding
        uint32_t size
        void (*callback)(void *userdata, uint8_t *stream, int len)
        void *userdata

    struct SDL_mutex:
        pass

    struct SDL_Thread:
        pass

    SDL_mutex *SDL_CreateMutex()
    void SDL_DestroyMutex(SDL_mutex *)
    int SDL_LockMutex(SDL_mutex *)
    int SDL_UnlockMutex(SDL_mutex *)

    struct SDL_cond:
        pass

    SDL_cond *SDL_CreateCond()
    void SDL_DestroyCond(SDL_cond *)
    int SDL_CondSignal(SDL_cond *)
    int SDL_CondWait(SDL_cond *, SDL_mutex *)

    struct SDL_Thread:
        pass

    ctypedef int (*SDLCALL)(void *)
    SDL_Thread *SDL_CreateThread(SDLCALL, void *data)
    void SDL_WaitThread(SDL_Thread *thread, int *status)
    uint32_t SDL_ThreadID()

    char *SDL_GetError()

    struct SDL_UserEvent:
        uint8_t type
        int code
        void *data1
        void *data2

    union SDL_Event:
        uint8_t type

    int SDL_PushEvent(SDL_Event *event)
    void SDL_Delay(int)
    int SDL_Init(int)
    void SDL_LockAudio()
    void SDL_UnlockAudio()

cdef extern from "SDL_mixer.h" nogil:
    struct Mix_Chunk:
        pass
    int Mix_Init(int)
    int Mix_OpenAudio(int frequency, uint16_t format, int channels, int chunksize)
    void Mix_Pause(int channel)
    void Mix_Resume(int channel)
    void Mix_CloseAudio()
    int Mix_PlayChannel(int channel, Mix_Chunk *chunk, int loops)
    int Mix_HaltChannel(int channel)
    ctypedef void (*Mix_EffectFunc_t)(int, void *, int, void *)
    ctypedef void (*Mix_EffectDone_t)(int, void *)
    int Mix_RegisterEffect(int chan, Mix_EffectFunc_t f, Mix_EffectDone_t d, void * arg)
    int Mix_UnregisterAllEffects(int chan)
    int Mix_AllocateChannels(int numchans)
    Mix_Chunk *Mix_QuickLoad_RAW(uint8_t *mem, uint32_t l)
    void Mix_FreeChunk(Mix_Chunk *chunk)
    int Mix_QuerySpec(int *frequency,uint16_t *format,int *channels)
    int Mix_Volume(int chan, int volume)


cdef void audio_callback(int chan, void *stream, int l, void *userdata) with gil:
    cdef AudioSample sample = <AudioSample>userdata
    cdef bytes b = <bytes>sample.audio_callback(sample, sample.index, l)
    if b is None:
        return
    if len(b) < l:
        print 'AudioSample: not enougth data from', sample
        return
    memcpy(stream, <void *><char *>b, l)
    sample.index += l

class AudioException(Exception):
    pass


cdef class AudioSample:

    cdef object audio_callback
    cdef int channel
    cdef Mix_Chunk *raw_chunk
    cdef AudioStream stream
    cdef unsigned int index

    def __cinit__(self, *args):
        self.channel = -1
        self.raw_chunk = NULL
        self.stream = None
        self.index = 0

    def __init__(self, audio_callback):
        self.audio_callback = audio_callback

    cdef void dealloc(self):
        if self.raw_chunk != NULL:
            Mix_FreeChunk(self.raw_chunk)
            self.raw_chunk = NULL

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
        SDL_LockAudio()
        Mix_RegisterEffect(self.channel, audio_callback, NULL, <void *>self)
        SDL_UnlockAudio()

    def play(self):
        if self.channel == -1:
            self.alloc()
        self.index = 0
        with nogil:
            Mix_PlayChannel(self.channel, self.raw_chunk, -1)

    def stop(self):
        with nogil:
            Mix_HaltChannel(self.channel)


cdef class AudioStream:

    cdef list samples
    cdef int audio_init
    cdef int rate
    cdef int channels
    cdef int buffersize
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

