#ifndef __AUDIOSTREAM_IOS_EXT
#define __AUDIOSTREAM_IOS_EXT

typedef void (*audio_callback_t)(char *buffer, int bufsize);
void audiostream_cy_register(audio_callback_t callback);

int as_ios_mic_init(int rate, int channels, int encoding);
int as_ios_mic_start(void);
int as_ios_mic_stop(void);
void as_ios_mic_deinit(void);

#endif
