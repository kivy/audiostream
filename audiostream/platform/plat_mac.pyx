__all__ = ('IosAudioInput', )

from audiostream import AudioInput

include "../config.pxi"

cdef extern from "mac_ext.h":
    ctypedef void (*audio_callback_t)(char *, int)
    void audiostream_cy_register(audio_callback_t)
    int as_mac_mic_init(int rate, int channels, int encoding)
    int as_mac_mic_start()
    int as_mac_mic_stop()
    void as_mac_mic_deinit()

py_audio_callback = None

class MacAudioInput(AudioInput):
    def start(self):
        global py_audio_callback
        py_audio_callback = self.callback
        ret = as_mac_mic_init(self.rate, self.channels, self.encoding)
        ret = as_mac_mic_start()

    def stop(self):
        py_audio_callback = None
        ret = as_mac_mic_stop()
        as_mac_mic_deinit()

cdef void cy_audio_callback(char *buf, int buffersize) nogil:
    with gil:
        if py_audio_callback is None:
            return
        py_audio_callback(buf[:buffersize])

cdef void init():
    audiostream_cy_register(cy_audio_callback)

# init the module on-load
init()
