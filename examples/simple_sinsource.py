from time import sleep
from audiostream import get_output
from audiostream.sources.wave import SineSource

# get a output stream where we can play samples
stream = get_output(channels=2, rate=22050, buffersize=128)

# create one wave sin() at 220Hz, attach it to our speaker, and play
sinsource = SineSource(stream, 220)
sinsource.start()

# you can change the frequency of the source during the playtime
for x in range(20):
    sinsource.frequency = 220 + x * 20
    sleep(.1)

# ok we are done, stop everything.
sinsource.stop()
