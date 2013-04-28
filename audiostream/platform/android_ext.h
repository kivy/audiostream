#ifndef __AUDIOSTREAM_ANDROID_EXT
#define __AUDIOSTREAM_ANDROID_EXT

#include <jni.h>
#include <stdio.h>
#include <android/log.h>
#include <string.h>

extern JNIEnv *SDL_ANDROID_GetJNIEnv();

typedef void (*audio_callback_t)(char *buffer, int bufsize);
static audio_callback_t audio_callback = NULL;
static int audiostream_jni_registered = 0;

JNIEXPORT void JNICALL
audiostream_native_audio_callback(JNIEnv* env, jobject thiz, jobject buf, jint bufsize)
{
	if ( audio_callback == NULL )
		return;

	jboolean iscopy;
    jbyte* bbuf = (*env)->GetDirectBufferAddress(env, buf);
	audio_callback((char *)bbuf, bufsize);
}

static JNINativeMethod methods[] = {
	{ "nativeAudioCallback", "(Ljava/nio/ByteBuffer;I)V", (void *)&audiostream_native_audio_callback }
};

void audiostream_jni_register() {
	if ( !audiostream_jni_registered ) {
		JNIEnv *env = SDL_ANDROID_GetJNIEnv();
		jclass cls = (*env)->FindClass(env, "org/audiostream/AudioIn");
		(*env)->RegisterNatives(env, cls, methods, sizeof(methods) / sizeof(methods[0]));
		audiostream_jni_registered = 1;
	}
}

void audiostream_cy_register(audio_callback_t callback) {
	audiostream_jni_register();
	audio_callback = callback;
}

#endif
