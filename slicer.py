class Slicer(object):
    def __init__(self, start=None, stop=None, step=None):
        self.start = start
        self.stop = stop
        self.step = step

    @property
    def length(self):
        return (self.stop - self.start) if self.stop is not None else self.start

    @property
    def index(self):
        return slice(self.start, self.stop, self.step)
