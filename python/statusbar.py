from multiprocessing import Queue
import sys
import time

class statusbar(object):
    def __init__(self, num_tasks):
        self.queue = Queue()
        self._barsize = 50
        self._num_tasks = num_tasks
        self._percent_increment = 100 / float(self._num_tasks)
        self._increment = 0
        self._increment_at = self._num_tasks / self._barsize

    def initialize(self):
        sys.stdout.write('\r')
        sys.stdout.write('[{:{}s}] {}%'.format('=' * 0, self._barsize, 0))
        sys.stdout.flush()

    def update(self, bars):
        if bars % self._increment_at == 0:
            self._increment += 1
        sys.stdout.write('\r')
        sys.stdout.write('[{:{}s}] {:.2f}%'.format('=' * self._increment, self._barsize, self._percent_increment * bars))
        sys.stdout.flush()

    def broadcast(self, index_list, i):
        increment_at = (index_list[-1] - index_list[0]) / self._barsize
        norm_i = i - index_list[0] + 1
        if norm_i % increment_at == 0:
            time.sleep(0.05) # allows time for status bar to update
            n = norm_i / increment_at
            self.queue.put(n)
            if n == self._barsize:
                self.queue.put('STOP')

    def run(self):
        start = time.time()
        self.initialize()
        for i in iter(self.queue.get, 'STOP'):
            self.update(i)
        return time.time() - start
