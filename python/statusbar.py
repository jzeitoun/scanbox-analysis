from multiprocessing import Queue
import sys
import time

class statusbar(object):
    def __init__(self, barsize):
        self.barsize = barsize
        self.increment = 100 / barsize
        self.queue = Queue()

    def initialize(self):
        sys.stdout.write('\r')
        sys.stdout.write('[{:{}s}] {}%'.format('=' * 0, self.barsize, 0))
        sys.stdout.flush()

    def update(self, bars):
        sys.stdout.write('\r')
        sys.stdout.write('[{:{}s}] {}%'.format('=' * bars, self.barsize, self.increment * bars))
        sys.stdout.flush()

    def broadcast(self, index_list, i):
        increment_at = (index_list[-1] - index_list[0]) / self.barsize
        norm_i = i - index_list[0] + 1
        if norm_i % increment_at == 0:
            time.sleep(0.05) # allows time for status bar to update
            n = norm_i / increment_at
            self.queue.put(n)
            if n == self.barsize:
                self.queue.put('STOP')

    def run(self):
        start = time.time()
        self.initialize()
        for i in iter(self.queue.get, 'STOP'):
            self.update(i)
        return time.time() - start
