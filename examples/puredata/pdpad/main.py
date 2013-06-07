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

from pylibpd import libpd_float, libpd_bang

CHANNELS = 2
BUFSIZE = 1024
SAMPLERATE = 44100

class TouchableStack(StackLayout):
    def __init__(self, app, *args, **kwargs):
        super(TouchableStack, self).__init__(*args, **kwargs)
        self.app = app

    def on_touch_down(self, touch):
        root = self.get_root_window()
        libpd_float('x', min(1.0, float(touch.x / root.width) + .33))
        libpd_float('y', min(1.0, float(touch.y / root.height) + .33))
        libpd_bang('trigger')

class AudioApp(App):
    def build(self):
        logo_pd = Image(source='pd.png', 
                        allow_stretch=True,)
        logo_kivy = Image(source='kivy.png', 
                          allow_stretch=True,)
        label = Label(text="kivy+pd://funpad.pd",
                      font_size=30)

        self.widget = TouchableStack(self)
        self.widget.add_widget(logo_pd)
        self.widget.add_widget(label)
        self.widget.add_widget(logo_kivy)
        self.stream = get_output(channels=CHANNELS, 
                                 buffersize=BUFSIZE, 
                                 rate=SAMPLERATE)
        self.source = PatchSource(self.stream, 'funpad.pd')
        self.source.start()

        return self.widget

AudioApp().run()
