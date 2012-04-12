import threading
from time import time
from array import array
from struct import pack

from kivy.app import App
from kivy.uix.stacklayout import StackLayout
from kivy.uix.image import Image
from kivy.uix.widget import Widget
from kivy.uix.label import Label

from kivy.config import Config
Config.set('graphics', 'maxfps', '30')

from audiostream import AudioStream, AudioSample, sine_wave, pd_wave

CHANNELS = 2
BUFSIZE = 4096 / 2
BLOCKSIZE = 128
SAMPLERATE = 44100

class ThreadSource(threading.Thread):
    """Threaded Waveform Generation"""
    def __init__(self, stream, samplerate, bufsize, blocksize):
        threading.Thread.__init__(self)
        self.daemon = True
        self.stream = stream
        self.samplerate = samplerate
        self.bufsize = bufsize
        self.blocksize = blocksize
        self.sample = AudioSample()
        stream.add_sample(self.sample)

    def get_bytes(self):
        return ''

    def run(self):
        self.sample.play()
        while True:
            self.sample.write(self.get_bytes())

class PDSource(ThreadSource):
    def __init__(self, *args, **kwargs):
        ThreadSource.__init__(self, *args, **kwargs)
        print "*"*20, dir(self.stream)
        self.snd_gen = pd_wave('bloopy.pd', self.samplerate, 
                               self.bufsize, self.blocksize)

    def get_bytes(self):
        return self.snd_gen.next()

class AudioApp(App):
    def build(self):
#        self.slider = Slider(min=110, max=880, value=440)
        logo_pd = Image(source='pd.png', 
                        allow_stretch=True,)
        logo_kivy = Image(source='kivy.png', 
                          allow_stretch=True,)
        label = Label(text="kivy+pd://bloopy.pd",
                      font_size=30)
                          
        self.widget = StackLayout()
        self.widget.add_widget(logo_pd)
        self.widget.add_widget(label)
        self.widget.add_widget(logo_kivy)
        self.stream = AudioStream(channels=CHANNELS, buffersize=BUFSIZE, rate=SAMPLERATE)
        self.source = PDSource(self.stream, SAMPLERATE, BUFSIZE, BLOCKSIZE)
        self.source.start()

        return self.widget
#        return self.slider

AudioApp().run()
