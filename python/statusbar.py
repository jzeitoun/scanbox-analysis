import sys

class Statusbar(object):
    def __init__(self, num_tasks, barsize=50):
        self._barsize = barsize
        self._num_tasks = num_tasks

    def initialize(self):
        sys.stdout.write('\r')
        sys.stdout.write('[{:{}s}] {}%'.format('=' * 0, self._barsize, 0))
        sys.stdout.flush()

    def update(self, bars):
        fraction_complete = bars/float(self._num_tasks)
        increment = int(self._barsize * fraction_complete)
        percent_increment = 100 * fraction_complete
        sys.stdout.write('\r')
        sys.stdout.write('[{:{}s}] {:.2f}%'.format('=' * increment, self._barsize, percent_increment))
        sys.stdout.flush()

