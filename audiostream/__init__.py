'''
Audiostream
===========

Audiostream is a python extension that gives you a direct access to the speaker
or microphone.

The goal of this project is act as low level as possible on the audio stream:

- You push bytes to the speaker
- You get bytes from the microphone
'''

__version__ = (0, 2)

__all__ = ('get_output', 'get_input', 'get_input_sources', 'AudioOutput',
    'AudioInput', 'AudioSample', 'AudioException')

from audiostream.core import *

