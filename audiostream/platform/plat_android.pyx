__all__ = ('AndroidAudioInput', )

from audiostream import AudioInput

include "../config.pxi"

cdef extern from "android_ext.h":
    ctypedef void (*audio_callback_t)(char *, int)
    void audiostream_jni_register()
    void audiostream_cy_register(audio_callback_t)

py_audio_callback = None
AudioIn = None

class AndroidAudioInput(AudioInput):
    # from http://developer.android.com/reference/android/media/AudioFormat.html#CHANNEL_IN_STEREO
    # it's easier to re-declare there than use pyjnius for introspect the
    # object.
    CHANNEL_IN_MONO = 0x10
    CHANNEL_IN_STEREO = 0x0c
    ENCODING_PCM_8BIT = 0x3
    ENCODING_PCM_16BIT = 0x2

    SOURCE_CAMCORDER = 0x05
    SOURCE_DEFAULT = 0x00
    SOURCE_MIC = 0x01
    SOURCE_VOICE_CALL = 0x04
    SOURCE_VOICE_COMMUNICATION = 0x07
    SOURCE_VOICE_DOWNLINK = 0x03
    SOURCE_VOICE_RECOGNITION = 0x06
    SOURCE_VOICE_UPLINK = 0x02

    def __init__(self, *args, **kwargs):
        super(AndroidAudioInput, self).__init__(*args, **kwargs)
        # check the configuration
        if not AudioIn.check_configuration(
                self.buffersize, self.rate, self.android_channels, self.android_encoding):
            raise Exception('Unable to use the audio configuration '
                    '(rate={} channels={} encoding={})'.format(self.rate,
                        self.channels, self.encoding))

    def start(self):
        global py_audio_callback
        py_audio_callback = self.callback
        AudioIn.start_recording(self.android_source, self.buffersize, self.rate,
                self.android_channels, self.android_encoding)

    def stop(self):
        global py_audio_callback
        py_audio_callback = None
        AudioIn.stop_recording()

    @property
    def android_channels(self):
        if self.channels == 1:
            return AndroidAudioInput.CHANNEL_IN_MONO
        return AndroidAudioInput.CHANNEL_IN_STEREO

    @property
    def android_encoding(self):
        if self.encoding == 8:
            return AndroidAudioInput.ENCODING_PCM_8BIT
        return AndroidAudioInput.ENCODING_PCM_16BIT

    @property
    def android_source(self):
        return {
            'camcorder': AndroidAudioInput.SOURCE_CAMCORDER,
            'default': AndroidAudioInput.SOURCE_DEFAULT,
            'mic': AndroidAudioInput.SOURCE_MIC,
            'voice_call': AndroidAudioInput.SOURCE_VOICE_CALL,
            'voice_communication': AndroidAudioInput.SOURCE_VOICE_COMMUNICATION,
            'voice_downlink': AndroidAudioInput.SOURCE_VOICE_DOWNLINK,
            'voice_recognition': AndroidAudioInput.SOURCE_VOICE_RECOGNITION,
            'voice_uplink': AndroidAudioInput.SOURCE_VOICE_UPLINK
            }.get(self.source)


cdef void cy_audio_callback(char *buf, int buffersize) nogil:
    with gil:
        if py_audio_callback is None:
            return
        py_audio_callback(buf[:buffersize])

cdef void init():
    global AudioIn

    # register native jni callback
    audiostream_jni_register()

    # register our cython callback
    audiostream_cy_register(cy_audio_callback)

    from jnius import autoclass
    AudioIn = autoclass('org.audiostream.AudioIn')

# init the module on-load.
init()
