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

cdef int rb_size(RingBuffer *rb) nogil:
    return rb.size

cdef int rb_maxlen(RingBuffer *rb) nogil:
    return rb.maxlen

cdef int rb_poll(RingBuffer *rb) nogil:
    # FIXME we assume that reading / assign an int is atomic.
    return 1 if rb.size > 0 else 0

cdef int rb_read_into(RingBuffer *rb, int bufsize, char *mem) nogil:
    cdef char *p = NULL
    cdef int size = bufsize
    cdef int datasize = bufsize

    SDL_LockMutex(rb.qmtx)
    if rb.size < size:
        size = datasize = rb.size
    SDL_UnlockMutex(rb.qmtx)

    p = mem
    while size > 0:
        chunk = rb_popleft(rb)
        if chunk == NULL:
            return -1

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

    # fill the end with 0
    if datasize < bufsize:
        memset(&mem[datasize], 0, bufsize - datasize)

    SDL_LockMutex(rb.condmtx)
    SDL_CondSignal(rb.cond)
    SDL_UnlockMutex(rb.condmtx)

    return datasize


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

