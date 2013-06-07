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

from audiostream import get_output
from audiostream.sources.puredata import PatchSource

CHANNELS = 2
BUFSIZE = 4096 / 2
SAMPLERATE = 44100

class AudioApp(App):
    def build(self):
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
        self.stream = get_output(channels=CHANNELS, buffersize=BUFSIZE, rate=SAMPLERATE)
        self.source = PatchSource(self.stream, 'bloopy.pd')
        self.source.start()

        return self.widget

AudioApp().run()
