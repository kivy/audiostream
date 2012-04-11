import threading
from time import sleep
from math import sin, pi
from struct import pack
from itertools import *
from functools import partial
from collections import deque
from array import array

from audiostream import AudioStream, AudioSample

CHANNELS = 2
BUFSIZE = 1024
INCSIZE = 512

class ThreadSource(threading.Thread):
    """Threaded Waveform Generation"""
    def __init__(self, stream, bufsize):
        threading.Thread.__init__(self)
        self.daemon = True
        self.bufsize = bufsize
        self.sample = AudioSample()
        stream.add_sample(self.sample)

    def get_bytes(self):
        buf = []
        buf.append(0)
        buf.append(0)
        return buf

    def run(self):
        self.sample.play()
        while True:
            self.sample.write(self.get_bytes())

class SineSource(ThreadSource):
    def __init__(self, *args, **kwargs):
        ThreadSource.__init__(self, *args, **kwargs)
        self.next_freq_left = self.next_freq_right = None
        self.gen_left = self.sine_wave()
        self.gen_right = self.sine_wave(frequency=220.0)

    def sine_wave(self, frequency=440.0, framerate=44100, amplitude=0.5, index=0):
        period = int(framerate / frequency)
        amplitude = max(0.0, min(1.0, float(amplitude)))
        lookup_table = []
        pi2 = 2.0 * pi
        for i in xrange(period):
            sincomp = sin(pi2*float(frequency)*(float(i%period)/float(framerate)))
            lookup_table.append(float(amplitude) * sincomp)
        return (lookup_table[(index + i)%period] for i in count(0))

    def get_bytes(self):
        buf = array('h', '\x00' * INCSIZE)
        f = (2 ** 16) / pi
        lvl = lvr = None
        i = 0
        glnext = self.gen_left.next
        grnext = self.gen_right.next
        while i < INCSIZE / 2:
            vl = glnext() * f
            vr = grnext() * f
            if self.next_freq_left and lvl == 0 and vl > 0:
                self.gen_left = self.sine_wave(frequency=self.next_freq_left)
                self.next_freq_left = None
                glnext = self.gen_left.next
                vl = glnext() * f
            if self.next_freq_right and lvr == 0 and vr > 0:
                self.gen_right = self.sine_wave(frequency=self.next_freq_right)
                self.next_freq_right = None
                grnext = self.gen_right.next
                vr = grnext() * f
            buf[i] = lvl = int(vl)
            buf[i+1] = lvr = int(vr)
            i += 2
        return buf.tostring()

from kivy.app import App
from kivy.uix.slider import Slider

class AudioApp(App):
    def build(self):
        self.stream = AudioStream(channels=CHANNELS, buffersize=BUFSIZE)
        self.slider = Slider(min=110, max=880, value=440)
        self.slider.bind(value=partial(self.update_freq))

        print "STARTING THREAD!!!"
        self.source = SineSource(self.stream, BUFSIZE)
        self.source.start()

        return self.slider

    def update_freq(self, slider, value):
        self.source.next_freq_left = value
        self.source.next_freq_right = value / 2

AudioApp().run()
