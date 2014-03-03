from audiostream import get_output, AudioSample
from math import sin, pi
from struct import pack
from itertools import *


def sine_wave(frequency=440.0, framerate=44100, amplitude=0.5, index=0):
    period = int(framerate / frequency)
    if amplitude > 1.0: amplitude = 1.0
    if amplitude < 0.0: amplitude = 0.0
    lookup_table = [float(amplitude) * sin(2.0*pi*float(frequency)*(float(i%period)/float(framerate))) for i in xrange(period)]
    return (lookup_table[(index + i)%period] for i in count(0))

from kivy.app import App
from kivy.uix.slider import Slider
from kivy.uix.gridlayout import GridLayout
from kivy.uix.button import Button
from functools import partial


class AudioApp(App):

    def build(self):
        root = GridLayout(padding=20, spacing=10, cols=4)
        self.stream = get_output(channels=2, buffersize=1024)
        self.gens = {}

        for x in xrange(20):
            sample = AudioSample(partial(self.audio_callback, x))
            self.stream.add_sample(sample)
            btn = Button(text='Sample %d' % x)
            btn.bind(state=partial(self.update_state, x))
            slider = Slider(min=110, max=880, value=440)
            slider.bind(value=partial(self.update_freq, x))
            root.add_widget(btn)
            root.add_widget(slider)

            # generators
            gen_left = sine_wave()
            gen_right = sine_wave(frequency=220.0)
            self.gens[x] = [sample, gen_left, gen_right, None, None]

        return root

    def update_freq(self, x, slider, value):
        self.gens[x][3] = value
        self.gens[x][4] = value / 2

    def update_state(self, x, instance, value):
        if value == 'down':
            self.gens[x][0].play()
        elif value == 'normal':
            self.gens[x][0].stop()

    def audio_callback(self, x, sample, index, bufsize):
        buf = []
        f = (2 ** 16) / pi
        lvl = lvr = None
        g = self.gens[x]
        gen_left, gen_right, next_freq_left, next_freq_right = g[1:]
        while len(buf) < bufsize / 2:
            vl = int(gen_left.next() * f)
            vr = int(gen_right.next() * f)
            if next_freq_left and lvl == 0 and vl > 0:
                g[1] = gen_left = sine_wave(frequency=next_freq_left)
                g[3] = next_freq_left = None
                vl = int(gen_left.next() * f)
            if next_freq_right and lvr == 0 and vr > 0:
                g[2] = gen_right = sine_wave(frequency=next_freq_right)
                g[4] = next_freq_right = None
                vr = int(gen_right.next() * f)
            lvl = vl
            lvr = vr
            buf.append(vl)
            buf.append(vr)
        return pack('h' * len(buf), *buf)


AudioApp().run()
