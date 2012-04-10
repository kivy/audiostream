from time import sleep
from audiostream import AudioStream, AudioSample
from math import sin, pi
from struct import pack
from itertools import *

def sine_wave(frequency=440.0, framerate=44100, amplitude=0.5):
    period = int(framerate / frequency)
    if amplitude > 1.0: amplitude = 1.0
    if amplitude < 0.0: amplitude = 0.0
    lookup_table = [float(amplitude) * sin(2.0*pi*float(frequency)*(float(i%period)/float(framerate))) for i in xrange(period)]
    return (lookup_table[i%period] for i in count(0))

gen_left = sine_wave()
gen_right = sine_wave(frequency=220.0)

def sin_callback(sample, index, bufsize):
    # must generate a buffer of l length
    buf = []
    f = (2 ** 16) / pi
    while len(buf) < bufsize / 2:
        vl = int(gen_left.next() * f)
        vr = int(gen_right.next() * f)
        buf.append(vl)
        buf.append(vr)
    return pack('h' * len(buf), *buf)

stream = AudioStream(channels=2, buffersize=1024)

# add a new sample to be played
sin_sample = AudioSample(sin_callback)
stream.add_sample(sin_sample)
sin_sample.play()

sleep(5)

# later, stop the stream
sin_sample.stop()
