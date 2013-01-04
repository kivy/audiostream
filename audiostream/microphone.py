__all__ = ('Microphone', )

class Microphone(object):
    def __init__(self, callback, source='default', rate=44100, channels=1,
            bufsize=-1, encoding=16):
        super(Microphone, self).__init__()
        if encoding not in (8, 16):
            raise Exception('Invalid encoding, must be one of 8, 16')
        if channels not in (1, 2):
            raise Exception('Invalid channels, must be one of 1, 2')
        self.callback = callback
        self.source = source
        self.rate = rate
        self.channels = channels
        self.bufsize = bufsize
        self.encoding = encoding

    def start(self):
        pass

    def stop(self):
        pass


