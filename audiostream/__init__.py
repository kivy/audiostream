'''
Audiostream
===========

Audiostream is a python extension that gives you a direct access to the speaker
or microphone.

The goal of this project is act as low level as possible on the audio stream:

    - You push bytes to the speaker
    - You get bytes from the microphone
'''

__version__ = (0, 1)
__all__ = ['AudioStream', 'AudioSample', 'AudioException']

from audiostream.core import AudioStream, AudioSample, AudioException
