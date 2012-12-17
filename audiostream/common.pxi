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


