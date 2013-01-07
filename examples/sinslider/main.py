from kivy.config import Config
Config.set('graphics', 'maxfps', '30')

from audiostream import get_output
from audiostream.sources.wave import SineSource

CHANNELS = 2
BUFSIZE = 2048
INCSIZE = 512

from kivy.app import App
from kivy.uix.slider import Slider

class AudioApp(App):
    def build(self):
        self.stream = get_output(channels=CHANNELS, buffersize=BUFSIZE, rate=22050)
        self.slider = Slider(min=110, max=880, value=440)
        self.slider.bind(value=self.update_freq)

        self.source = SineSource(self.stream, 440)
        self.source.start()

        return self.slider

    def update_freq(self, slider, value):
        #value = int(value / 50) * 50
        if value != self.source.frequency:
            self.source.frequency = value


AudioApp().run()
