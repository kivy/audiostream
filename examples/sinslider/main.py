from time import sleep
from audiostream import AudioStream, AudioSample
from math import sin, pi
from struct import pack
from itertools import *

def sine_wave(frequency=440.0, framerate=44100, amplitude=0.5, index=0):
    period = int(framerate / frequency)
    if amplitude > 1.0: amplitude = 1.0
    if amplitude < 0.0: amplitude = 0.0
    lookup_table = [float(amplitude) * sin(2.0*pi*float(frequency)*(float(i%period)/float(framerate))) for i in xrange(period)]
    return (lookup_table[(index + i)%period] for i in count(0))

next_freq_left = next_freq_right = None
gen_left = sine_wave()
gen_right = sine_wave(frequency=220.0)

def sin_callback(sample, index, bufsize):
    buf = []
    f = (2 ** 16) / pi
    lvl = lvr = None
    while len(buf) < bufsize / 2:
        vl = int(gen_left.next() * f)
        vr = int(gen_right.next() * f)
        if next_freq_left and lvl == 0 and vl > 0:
            global gen_left, next_freq_left
            gen_left = sine_wave(frequency=next_freq_left)
            next_freq_left = None
            vl = int(gen_left.next() * f)
        if next_freq_right and lvr == 0 and vr > 0:
            global gen_right, next_freq_right
            gen_right = sine_wave(frequency=next_freq_right)
            next_freq_right = None
            vr = int(gen_right.next() * f)
        lvl = vl
        lvr = vr
        buf.append(vl)
        buf.append(vr)
    return pack('h' * len(buf), *buf)

'''
stream = AudioStream(channels=2, buffersize=1024)

# add a new sample to be played
sin_sample = AudioSample(sin_callback)
stream.add_sample(sin_sample)
sin_sample.play()

sleep(5)

# later, stop the stream
sin_sample.stop()
'''

from kivy.app import App
from kivy.uix.slider import Slider

class AudioApp(App):
    def build(self):
        self.stream = AudioStream(channels=2, buffersize=1024)
        self.slider = Slider(min=110, max=880, value=440)
        self.slider.bind(value=self.update_freq)

        self.sample = AudioSample(sin_callback)
        self.stream.add_sample(self.sample)
        self.sample.play()
        return self.slider

    def update_freq(self, slider, value):
        global next_freq_left, next_freq_right
        next_freq_left = value
        next_freq_right = value / 2

AudioApp().run()

