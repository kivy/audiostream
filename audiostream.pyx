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
from libc.math cimport sin

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
    char *Mix_GetError()
    ctypedef void (*Mix_EffectFunc_t)(int, void *, int, void *)
    ctypedef void (*Mix_EffectDone_t)(int, void *)
    int Mix_RegisterEffect(int chan, Mix_EffectFunc_t f, Mix_EffectDone_t d, void * arg)
    int Mix_UnregisterAllEffects(int chan)
    int Mix_AllocateChannels(int numchans)
    Mix_Chunk *Mix_QuickLoad_RAW(uint8_t *mem, uint32_t l)
    void Mix_FreeChunk(Mix_Chunk *chunk)
    int Mix_QuerySpec(int *frequency,uint16_t *format,int *channels)
    int Mix_Volume(int chan, int volume)


class AudioException(Exception):
    pass

def sine_wave(float frequency=440.0, int framerate=22050, float amplitude=0.5):
    cdef int i, period
    cdef float pi2, sincomp
    cdef list lookup_table
    cdef float pi = 3.141592653589793
    cdef float f = 65535 / pi
    period = int(framerate / frequency)
    amplitude = max(0.0, min(1.0, amplitude))
    lookup_table = []
    pi2 = 2.0 * pi
    for i in xrange(period):
        sincomp = sin(pi2*float(frequency)*(float(i%period)/float(framerate)))
        lookup_table.append(<short>(amplitude * sincomp * f))

    try:
        i = 0
        while True:
            yield lookup_table[i % period]
            i += 1
    except StopIteration:
        return


ctypedef struct RingBufferChunk:
    char *data
    char *mem
    int size
    RingBufferChunk *next

ctypedef struct RingBuffer:
    int maxlen
    SDL_cond *cond
    SDL_mutex *condmtx
    SDL_mutex *qmtx
    int size
    RingBufferChunk *first
    RingBufferChunk *last

cdef RingBuffer *rb_new(int maxlen) nogil:
    cdef RingBuffer *rb = <RingBuffer *>malloc(sizeof(RingBuffer))
    rb.cond = SDL_CreateCond()
    rb.condmtx = SDL_CreateMutex()
    rb.qmtx = SDL_CreateMutex()
    rb.maxlen = maxlen
    rb.size = 0
    rb.first = rb.last = NULL
    return rb

cdef RingBufferChunk *rb_chunk_new(int size, char *mem) nogil:
    cdef RingBufferChunk *chunk = <RingBufferChunk *>malloc(sizeof(RingBufferChunk))
    chunk.mem = chunk.data = <char *>malloc(size)
    memcpy(chunk.mem, mem, size)
    chunk.size = size
    chunk.next = NULL
    return chunk

cdef void rb_chunk_free(RingBufferChunk *chunk) nogil:
    free(chunk.mem)
    chunk.mem = NULL

cdef void rb_free(RingBuffer *rb) nogil:
    cdef RingBufferChunk *chunk = rb.first
    while chunk != NULL:
        rb.first = chunk.next
        rb_chunk_free(chunk)
        chunk = rb.first
    SDL_DestroyMutex(rb.condmtx)
    SDL_DestroyMutex(rb.qmtx)
    SDL_DestroyCond(rb.cond)

cdef void rb_appendleft(RingBuffer *rb, RingBufferChunk *chunk) nogil:
    SDL_LockMutex(rb.qmtx)
    if rb.first == NULL:
        rb.first = rb.last = chunk
    else:
        chunk.next = rb.first
        rb.first = chunk
    rb.size += chunk.size
    SDL_UnlockMutex(rb.qmtx)

cdef void rb_append(RingBuffer *rb, RingBufferChunk *chunk) nogil:
    SDL_LockMutex(rb.qmtx)
    if rb.last == NULL:
        rb.last = rb.first = chunk
    else:
        rb.last.next = chunk
        rb.last = chunk
    rb.size += chunk.size
    SDL_UnlockMutex(rb.qmtx)

cdef RingBufferChunk *rb_popleft(RingBuffer *rb) nogil:
    cdef RingBufferChunk *chunk = NULL
    SDL_LockMutex(rb.qmtx)
    chunk = rb.first
    if chunk == NULL:
        return NULL
    rb.first = chunk.next
    if rb.first == NULL:
        rb.last = NULL
    rb.size -= chunk.size
    SDL_UnlockMutex(rb.qmtx)
    chunk.next = NULL
    return chunk

cdef void rb_write(RingBuffer *rb, int size, char *cbuf) nogil:
    cdef RingBufferChunk *chunk = rb_chunk_new(size, cbuf)
    SDL_LockMutex(rb.condmtx)
    while rb.size > rb.maxlen:
        SDL_CondWait(rb.cond, rb.condmtx)
    SDL_UnlockMutex(rb.condmtx)
    rb_append(rb, chunk)

cdef char *rb_read(RingBuffer *rb, int size) nogil:
    cdef RingBufferChunk *chunk = NULL
    cdef char *mem = NULL, *p = NULL

    SDL_LockMutex(rb.qmtx)
    if rb.size < size:
        SDL_UnlockMutex(rb.qmtx)
        return NULL
    SDL_UnlockMutex(rb.qmtx)

    p = mem = <char *>malloc(size)
    while size > 0:
        chunk = rb_popleft(rb)
        if chunk == NULL:
            free(mem)
            return NULL

        if chunk.size <= size:
            # full copy ?
            memcpy(p, chunk.data, chunk.size)
            p += chunk.size
            size -= chunk.size
            rb_chunk_free(chunk)

        else:
            # partial copy
            memcpy(p, chunk.data, size)
            chunk.data += size
            chunk.size -= size
            size = 0
            rb_appendleft(rb, chunk)

    SDL_LockMutex(rb.condmtx)
    SDL_CondSignal(rb.cond)
    SDL_UnlockMutex(rb.condmtx)

    return mem

cdef void audio_callback(int chan, void *stream, int l, void *userdata) nogil:
    cdef RingBuffer *rb = <RingBuffer *>userdata
    cdef char *cbuf = rb_read(rb, l)
    if cbuf == NULL:
        return
    memcpy(stream, <void *>cbuf, l)
    free(cbuf)

cdef class AudioSample:

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

