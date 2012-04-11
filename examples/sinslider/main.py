import threading
from kivy.config import Config
Config.set('graphics', 'maxfps', '30')
from time import time
from array import array

from audiostream import AudioStream, AudioSample, sine_wave

CHANNELS = 2
BUFSIZE = 2048
INCSIZE = 512

timeit_table = [0] * 100
timeit_index = 0
def timeit(f):
    def f2(*a, **b):
        global timeit_index
        timeit_index = (timeit_index + 1) % 100
        start = time()
        ret = f(*a, **b)
        timeit_table[timeit_index] = time() - start
        if timeit_index == 0:
            print 'timit %fms' % (100 * sum(timeit_table) / float(len(timeit_table)))
        return ret
    return f2

class ThreadSource(threading.Thread):
    """Threaded Waveform Generation"""
    def __init__(self, stream, bufsize):
        threading.Thread.__init__(self)
        self.daemon = True
        self.bufsize = bufsize
        self.sample = AudioSample()
        stream.add_sample(self.sample)

    def get_bytes(self):
        return ''

    def run(self):
        self.sample.play()
        while True:
            self.sample.write(self.get_bytes())

class SineSource(ThreadSource):
    def __init__(self, *args, **kwargs):
        ThreadSource.__init__(self, *args, **kwargs)
        self.next_gen_left = self.next_gen_right = None
        self.freq = 220.0
        self.gen_left = sine_wave()
        self.gen_right = sine_wave(frequency=220.0)

    #@timeit
    def get_bytes(self):
        buf = array('h', '\x00' * INCSIZE)
        lvl = lvr = None
        i = 0
        glnext = self.gen_left.next
        grnext = self.gen_right.next
        next_gen_left = self.next_gen_left
        next_gen_right = self.next_gen_right
        while i < INCSIZE / 2:
            vl = glnext()
            vr = grnext()
            if next_gen_left and lvl == 0 and vl > 0:
                self.gen_left = self.next_gen_left
                glnext = self.gen_left.next
                self.next_gen_left = next_gen_left = None
                vl = glnext()
            if next_gen_right and lvr == 0 and vr > 0:
                self.gen_right = self.next_gen_right
                grnext = self.gen_right.next
                self.next_gen_right = next_gen_right = None
                vr = grnext()
            buf[i] = lvl = vl
            buf[i+1] = lvr = vr
            i += 2
        return buf.tostring()

from kivy.app import App
from kivy.uix.slider import Slider

class AudioApp(App):
    def build(self):
        self.stream = AudioStream(channels=CHANNELS, buffersize=BUFSIZE, rate=22050)
        self.slider = Slider(min=110, max=880, value=440)
        self.slider.bind(value=self.update_freq)

        print "STARTING THREAD!!!"
        self.source = SineSource(self.stream, BUFSIZE)
        self.source.start()

        return self.slider

    def update_freq(self, slider, value):
        #value = int(value / 50) * 50
        if value != self.source.freq:
            self.source.next_gen_left = sine_wave(frequency=value)
            self.source.next_gen_right = sine_wave(frequency=value / 2)
            self.source.freq = value


AudioApp().run()
